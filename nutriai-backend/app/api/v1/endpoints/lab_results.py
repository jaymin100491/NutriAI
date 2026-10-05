from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.schemas.lab_result import LabResultResponse, LabResultListResponse, LabSyncResponse, PortalImportRequest
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
