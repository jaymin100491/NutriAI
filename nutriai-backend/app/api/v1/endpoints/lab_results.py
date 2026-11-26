import logging
import threading
import time
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.schemas.lab_result import (
    LabResultResponse,
    LabResultListResponse,
    LabSyncResponse,
    PortalImportRequest,
    PasteLabRequest,
)
from app.core.security import get_current_user
from app.db.database import get_db
from app.db import repository as repo
from app.db.store import get_user_preferences, set_user_goals, set_user_preferences
from app.services.lab_result_service import (
    get_lab_results_for_user,
    get_lab_result_by_id,
    get_latest_lab_result,
    sync_lab_results,
    import_portal_results_for_user,
    get_nutrition_relevant_history,
)
from app.services.lab_paste_parser import build_pasted_lab_result, extract_patient_demographics
from app.services.pdf_lab_extractor import extract_text_from_pdf
from app.services.goal_service import derive_goals_from_labs
from app.services.ai_meal_generator import ai_meal_generation_enabled_for
from app.services.weekly_plan_service import generate_weekly_plan
from app.integrations.registry import list_health_systems

router = APIRouter()
logger = logging.getLogger(__name__)

_plan_jobs: Dict[int, Dict[str, Any]] = {}
_plan_lock = threading.Lock()


def _run_plan_job(user_id: int, user_payload: Dict[str, Any], lab_summary: Optional[str]) -> None:
    try:
        plan = generate_weekly_plan(user_payload, for_next_week=False, lab_summary=lab_summary)
        with _plan_lock:
            _plan_jobs[user_id] = {
                "status": "done",
                "finished_at": time.time(),
                "plan_id": (plan or {}).get("id"),
                "generation_source": (plan or {}).get("generation_source"),
                "message": "Weekly plan generated",
            }
    except Exception as exc:
        logger.exception("Background plan generation failed for user %s", user_id)
        with _plan_lock:
            _plan_jobs[user_id] = {
                "status": "error",
                "finished_at": time.time(),
                "error": str(exc),
                "message": "Plan generation failed",
            }


@router.get("", response_model=LabResultListResponse)
async def get_lab_results(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = int(current_user["id"])
    user = repo.get_user_by_id(db, user_id)
    results = get_lab_results_for_user(db, user_id)

    return {
        "lab_results": results,
        "total": len(results),
        "source": "health_records",
        "patient_pid": user.labcorp_patient_id if user else None,
    }


@router.post("/sync", response_model=LabSyncResponse)
async def sync_lab_results_endpoint(
    health_system: str = "labcorp",
    source: str = "labcorp",
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = int(current_user["id"])
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    try:
        results = await sync_lab_results(db, user, health_system_id=health_system, source=source)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to sync lab results: {exc}",
        ) from exc

    return {
        "synced_count": len(results),
        "lab_results": results,
        "message": f"Synced {len(results)} lab results into your nutrition profile",
    }


@router.post("/import-from-portal", response_model=LabSyncResponse)
async def import_lab_results_from_portal(
    payload: PortalImportRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Accept lab data fetched by the browser from portal-api (withCredentials).
    Same trust model as patient-website-ui running on patient-local.labcorp.com:4200.
    """
    user_id = int(current_user["id"])
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    try:
        results = import_portal_results_for_user(db, user, payload.headers, payload.reports)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to import lab results: {exc}",
        ) from exc

    return {
        "synced_count": len(results),
        "lab_results": results,
        "message": f"Imported {len(results)} results from browser portal session",
    }


def _ingest_lab_text_and_plan(
    *,
    db: Session,
    current_user: dict,
    user,
    text: str,
    test_date: Optional[str] = None,
    panel_title: Optional[str] = None,
    source_label: str = "pasted_panel",
    generate_plan: bool = True,
) -> dict:
    """Store parsed labs, derive goals, optionally generate Mon–Sun weekly plan."""
    user_id = int(user.id)
    patient_name = f"{user.first_name or ''} {user.last_name or ''}".strip() or "Patient"
    panel = build_pasted_lab_result(
        user_id=user_id,
        text=text,
        test_date=test_date,
        panel_title=panel_title,
        source_label=source_label,
        patient_name=patient_name,
    )
    repo.upsert_lab_results(db, user_id, [panel])
    results = get_lab_results_for_user(db, user_id)

    # Persist Sex/DOB from Labcorp headers so BMR/TDEE can use real demographics
    demo = extract_patient_demographics(text)
    if demo:
        prefs = get_user_preferences(user_id)
        prefs.update({k: v for k, v in demo.items() if v})
        set_user_preferences(user_id, prefs)

    goals = derive_goals_from_labs(results, current_user)
    set_user_goals(user_id, goals)

    marker_count = len(panel.get("results", {}).get("tests", []))
    base = {
        "synced_count": 1,
        "lab_results": results,
        "goals": goals,
        "markers_saved": marker_count,
        "test_date": panel.get("test_date"),
        "panel_title": panel.get("panel_title"),
    }

    if not generate_plan:
        return {
            **base,
            "plan": None,
            "plan_status": "skipped",
            "message": (
                f"Saved {marker_count} markers from {panel.get('test_date')} "
                f"({panel.get('panel_title')}). Upload remaining PDFs, then generate the plan."
            ),
        }

    lab_summary = (panel.get("interpretation") or {}).get("summary")
    user_payload = {
        **current_user,
        "id": user_id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "subscription_tier": user.subscription_tier,
    }

    # AI week builds can exceed browser timeouts — run in background for allowlisted users.
    if ai_meal_generation_enabled_for(user_payload):
        with _plan_lock:
            current = _plan_jobs.get(user_id) or {}
            if current.get("status") != "running":
                _plan_jobs[user_id] = {
                    "status": "running",
                    "started_at": time.time(),
                    "message": "OpenAI plan generation started",
                }
                threading.Thread(
                    target=_run_plan_job,
                    args=(user_id, user_payload, lab_summary),
                    daemon=True,
                    name=f"lab-plan-{user_id}",
                ).start()
        return {
            **base,
            "plan": None,
            "plan_status": "running",
            "message": (
                f"Saved {marker_count} markers and derived {len(goals)} goals. "
                "OpenAI Mon–Sun plan is generating (usually 1–2 minutes) — hang tight."
            ),
        }

    plan = generate_weekly_plan(user_payload, for_next_week=False, lab_summary=lab_summary)
    return {
        **base,
        "plan": plan,
        "plan_status": "done",
        "message": (
            f"Saved {marker_count} markers, derived {len(goals)} goals, "
            f"and built your Mon–Sun plan ({plan.get('week_start')} → {plan.get('week_end')})."
        ),
    }


@router.post("/paste")
async def paste_lab_results(
    payload: PasteLabRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Paste lab markers → store → derive goals → generate this week's Mon–Sun plan."""
    user_id = int(current_user["id"])
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    text = (payload.text or "").strip()
    if len(text) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Paste at least one lab marker line from your results panel.",
        )

    try:
        return _ingest_lab_text_and_plan(
            db=db,
            current_user=current_user,
            user=user,
            text=text,
            test_date=payload.test_date,
            panel_title=payload.panel_title,
            source_label=payload.source_label or "pasted_panel",
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/upload-pdf")
async def upload_lab_pdf(
    file: UploadFile = File(...),
    test_date: Optional[str] = None,
    generate_plan: bool = True,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Upload a lab PDF → extract text → store markers. Optionally build Mon–Sun plan."""
    user_id = int(current_user["id"])
    user = repo.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Please upload a PDF file")

    raw = await file.read()
    if len(raw) > 12_000_000:
        raise HTTPException(status_code=400, detail="PDF too large (max 12MB)")

    try:
        text, pages = extract_text_from_pdf(raw)
        result = _ingest_lab_text_and_plan(
            db=db,
            current_user=current_user,
            user=user,
            text=text,
            test_date=test_date,
            panel_title=f"Uploaded PDF ({file.filename})",
            source_label="pdf_upload",
            generate_plan=generate_plan,
        )
        result["pdf_pages"] = pages
        result["filename"] = file.filename
        result["message"] = f"Processed {pages}-page PDF ({file.filename}). " + result["message"]
        return result
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/plan-job-status")
async def lab_plan_job_status(current_user: dict = Depends(get_current_user)):
    """Poll background OpenAI plan generation started by PDF/paste import."""
    user_id = int(current_user["id"])
    with _plan_lock:
        job = dict(_plan_jobs.get(user_id) or {})
    if not job:
        return {"status": "idle", "message": "No plan job in progress"}
    return job


@router.get("/trends")
async def get_lab_trends(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    chronolab-rag style multi-visit lab trends for the Trends tab.
    Deterministic math on stored panels (no LLM required).
    """
    from app.services.lab_trend_service import build_lab_trends

    user_id = int(current_user["id"])
    results = get_lab_results_for_user(db, user_id)
    return build_lab_trends(results, patient_id=str(current_user.get("email") or user_id))


@router.get("/latest", response_model=LabResultResponse)
async def get_latest_lab_result_endpoint(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = int(current_user["id"])
    latest = await get_latest_lab_result(db, user_id)

    if not latest:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No lab results found — tap Sync Labs")
    return latest


@router.get("/history/nutrition", response_model=LabResultListResponse)
async def get_nutrition_lab_history(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = int(current_user["id"])
    user = repo.get_user_by_id(db, user_id)
    results = get_nutrition_relevant_history(db, user_id)
    return {
        "lab_results": results,
        "total": len(results),
        "source": "health_records",
        "patient_pid": user.labcorp_patient_id if user else None,
    }


@router.get("/health-systems")
async def list_supported_health_systems():
    return {
        "health_systems": list_health_systems(),
        "primary_integration": {
            "name": "Connected health records (MyChart / EHR)",
            "environment": "demo",
            "auth": "Open account login",
            "fulfillment": "Follow-up lab scheduling via Labcorp only",
        },
        "current_import": {
            "method": "copy_paste",
            "note": "Users paste panel text today; automatic multi-system fetch is the roadmap.",
        },
    }


@router.get("/sample-lab-order")
async def get_my_sample_lab_order(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Sample Labcorp-style wellness lab order for the signed-in user (DEMO ONLY).
    Used for retest-ready cohort personas during stakeholder demos.
    """
    from app.services.lab_order_service import build_sample_lab_order

    try:
        return build_sample_lab_order(db, int(current_user["id"]))
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/{result_id}", response_model=LabResultResponse)
async def get_lab_result_detail(
    result_id: int,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = int(current_user["id"])
    result = await get_lab_result_by_id(db, user_id, result_id)

    if not result:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lab result not found")
    return result
