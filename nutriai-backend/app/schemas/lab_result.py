from pydantic import BaseModel
from typing import Dict, List, Any, Optional


class LabcorpMetadata(BaseModel):
    pid: Optional[int] = None
    patient_name: str
    account_name: str
    ordering_provider: str
    dashboard_category: str
    date_of_service: str
    ordered_date: str
    report_date: str
    is_detail_available: bool
    test_codes: List[Dict[str, str]]


class LabResultResponse(BaseModel):
    id: int
    user_id: int
    test_date: str
    panel_title: Optional[str] = None
    source: str = "labcorp"
    results: Dict[str, Any]
    interpretation: Optional[Dict[str, Any]] = None
    labcorp: Optional[LabcorpMetadata] = None

    class Config:
        from_attributes = True


class LabResultListResponse(BaseModel):
    lab_results: List[LabResultResponse]
    total: int
    source: str = "labcorp"
    patient_pid: Optional[int] = None


class LabSyncResponse(BaseModel):
    synced_count: int
    lab_results: List[LabResultResponse]
    message: str


class PortalImportRequest(BaseModel):
    """Raw patient portal JSON fetched from the browser (same as patient-website-ui)."""
    headers: List[Dict[str, Any]]
    reports: List[Dict[str, Any]] = []


class PasteLabRequest(BaseModel):
    """Copy-paste lab panel text from MyChart / Labcorp / employer portal."""
    text: str
    test_date: Optional[str] = None
    panel_title: Optional[str] = None
    source_label: Optional[str] = "pasted_panel"
