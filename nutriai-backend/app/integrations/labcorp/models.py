"""Labcorp / eLabCorp API data models (patient portal format)."""
from __future__ import annotations

from typing import List, Optional
from pydantic import BaseModel, Field


class LabcorpResultCode(BaseModel):
    result_code: str = Field(alias="resultCode")
    result_name: str = Field(alias="resultName")

    class Config:
        populate_by_name = True


class LabcorpTestCode(BaseModel):
    test_code: str = Field(alias="testCode")
    test_name: str = Field(alias="testName")
    result_codes: List[LabcorpResultCode] = Field(alias="resultCodes")

    class Config:
        populate_by_name = True


class LabcorpResultSummary(BaseModel):
    """List-item from patient lab results dashboard API."""
    id: int
    test_codes: List[LabcorpTestCode] = Field(alias="testCodes")
    account_name: str = Field(alias="accountName")
    ordering_provider_name: str = Field(alias="orderingProviderName")
    date_of_service: str = Field(alias="dateOfService")
    ordered_date: str = Field(alias="orderedDate")
    report_date: str = Field(alias="reportDate")
    dashboard_category: str = Field(alias="dashboardCategory")
    we_health_eligible: bool = Field(alias="weHealthEligible")
    pid: int
    patient_name: str = Field(alias="patientName")
    is_detail_available: bool = Field(alias="isDetailAvailable")
    has_minimum_data_for_pdf_retrieval: bool = Field(alias="hasMinimumDataForPdfRetrieval")

    class Config:
        populate_by_name = True


class LabcorpResultDetailItem(BaseModel):
    """Individual analyte from result detail API."""
    result_code: str = Field(alias="resultCode")
    result_name: str = Field(alias="resultName")
    test_code: Optional[str] = Field(None, alias="testCode")
    value: str
    unit: Optional[str] = None
    reference_range: Optional[str] = Field(None, alias="referenceRange")
    abnormal_flag: Optional[str] = Field(None, alias="abnormalFlag")  # H, L, A, N
    status: Optional[str] = None  # normal, high, low

    class Config:
        populate_by_name = True


class LabcorpResultDetail(BaseModel):
    """Full result detail — values + reference ranges."""
    id: int
    pid: int
    patient_name: str = Field(alias="patientName")
    date_of_service: str = Field(alias="dateOfService")
    report_date: str = Field(alias="reportDate")
    ordering_provider_name: str = Field(alias="orderingProviderName")
    account_name: str = Field(alias="accountName")
    results: List[LabcorpResultDetailItem]

    class Config:
        populate_by_name = True
