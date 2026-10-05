from fastapi import APIRouter, Depends, HTTPException, status
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
from app.services.lab_result_service import (
    get_lab_results_for_user,
    get_lab_result_by_id,
    get_latest_lab_result,
    sync_lab_results,
    import_portal_results_for_user,
    get_nutrition_relevant_history,
)
from app.services.lab_paste_parser import build_pasted_lab_result
from app.integrations.registry import list_health_systems

router = APIRouter()


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


@router.post("/paste", response_model=LabSyncResponse)
async def paste_lab_results(
    payload: PasteLabRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Demo-friendly import: user pastes lab panel text from MyChart / Labcorp / any portal.
    Stored in NutriAI DB. Future: automatic EHR sync replaces this step.
    """
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
        patient_name = f"{user.first_name or ''} {user.last_name or ''}".strip() or "Patient"
        panel = build_pasted_lab_result(
            user_id=user_id,
            text=text,
            test_date=payload.test_date,
            panel_title=payload.panel_title,
            source_label=payload.source_label or "pasted_panel",
            patient_name=patient_name,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    repo.upsert_lab_results(db, user_id, [panel])
    results = get_lab_results_for_user(db, user_id)
    marker_count = len(panel.get("results", {}).get("tests", []))

    return {
        "synced_count": 1,
        "lab_results": results,
        "message": (
            f"Saved {marker_count} markers from pasted panel. "
            "Later this will sync automatically from connected health systems."
        ),
    }


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
