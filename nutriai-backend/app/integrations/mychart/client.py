"""
Epic MyChart integration via SMART on FHIR.

Novant (and Atrium, Cone Health) patients see Labcorp results inside MyChart.
We read them through Epic's FHIR R4 API — no separate Labcorp login needed.

Integration steps (production):
  1. Register NutriAI as SMART on FHIR app with Novant/Epic app orchard
  2. Patient authorizes via MyChart OAuth (scopes: patient/Observation.read,
     patient/DiagnosticReport.read, patient/Patient.read)
  3. Fetch Observation + DiagnosticReport resources
  4. Transform to NutriAI canonical format (same as Labcorp adapter output)

FHIR resources we care about:
  - DiagnosticReport: lab panel header (date, ordering provider, status)
  - Observation: individual analyte (glucose, cholesterol, etc.)
  - Patient: demographics linkage
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

# Epic FHIR → NutriAI status mapping
FHIR_INTERPRETATION_MAP = {
    "H": "high",
    "HH": "high",
    "L": "low",
    "LL": "low",
    "N": "normal",
    "A": "high",
    "": "normal",
}

# LOINC codes for nutrition-relevant observations
NUTRITION_LOINC_CODES = {
    "2345-7": "Glucose",
    "2093-3": "Total Cholesterol",
    "18262-6": "LDL Cholesterol",
    "2085-9": "HDL Cholesterol",
    "2571-8": "Triglycerides",
    "4548-4": "HbA1c",
    "1989-3": "Vitamin D",
    "14749-6": "Glucose (Fasting)",
    "2951-2": "Sodium",
    "2823-3": "Potassium",
}


class MyChartClient:
    """
    Epic MyChart FHIR client (SMART on FHIR).

    Mock mode returns sample FHIR bundles transformed from Labcorp data
    so the full pipeline can be tested before Epic app registration.
    """

    def __init__(self, fhir_base_url: str = "", client_id: str = "", use_mock: bool = True):
        self.fhir_base_url = fhir_base_url
        self.client_id = client_id
        self.use_mock = use_mock
        self._access_token: Optional[str] = None

    def set_access_token(self, token: str) -> None:
        """Called after MyChart OAuth callback."""
        self._access_token = token

    @property
    def is_connected(self) -> bool:
        return self._access_token is not None or self.use_mock

    async def fetch_diagnostic_reports(self, patient_fhir_id: str) -> List[Dict[str, Any]]:
        if not self.use_mock:
            raise NotImplementedError(
                "Live MyChart FHIR — complete SMART on FHIR OAuth and Epic app registration"
            )
        from app.integrations.mychart.sample_fhir import MOCK_FHIR_BUNDLES
        return [b for b in MOCK_FHIR_BUNDLES if b.get("patient_id") == patient_fhir_id]

    async def fetch_observations_for_report(self, report_id: str) -> List[Dict[str, Any]]:
        if not self.use_mock:
            raise NotImplementedError("Live MyChart FHIR observation fetch")
        from app.integrations.mychart.sample_fhir import MOCK_OBSERVATIONS
        return MOCK_OBSERVATIONS.get(report_id, [])

    def get_authorization_url(self, health_system_id: str, redirect_uri: str) -> str:
        """Build Epic SMART on FHIR authorization URL for patient login."""
        from app.integrations.registry import get_integration
        integration = get_integration(health_system_id)
        if not integration or not integration.get("fhir_base_url"):
            raise ValueError(f"No FHIR endpoint configured for {health_system_id}")

        base = integration["fhir_base_url"]
        client_id = integration.get("mychart_app_id") or self.client_id
        scopes = "launch/patient patient/Observation.read patient/DiagnosticReport.read patient/Patient.read"

        return (
            f"{base}/oauth2/authorize"
            f"?response_type=code"
            f"&client_id={client_id}"
            f"&redirect_uri={redirect_uri}"
            f"&scope={scopes.replace(' ', '%20')}"
            f"&aud={base}"
            f"&state={health_system_id}"
        )


mychart_client = MyChartClient(use_mock=True)
