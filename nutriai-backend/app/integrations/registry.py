"""
Health system integration registry.

Enterprise lab data can arrive via multiple channels:

  Novant patient → MyChart (Epic) → DiagnosticReport/Observation (FHIR)
                 → Labcorp (performing lab) → same results, different API

  Atrium patient → MyChart / Epic → FHIR
  Cone Health    → MyChart / Epic → FHIR

NutriAI normalizes ALL sources into one canonical lab result format.
The diet plan engine never cares where results came from.
"""
from __future__ import annotations

from enum import Enum
from typing import Any, Dict, List, Optional


class LabDataSource(str, Enum):
    LABCORP = "labcorp"           # Direct Labcorp patient portal API
    MYCHART = "mychart"           # Epic MyChart FHIR (SMART on FHIR)
    LEGACY = "legacy"             # Internal mock / demo data


# Health systems and their primary patient-facing + lab channels
HEALTH_SYSTEM_INTEGRATIONS: Dict[str, Dict[str, Any]] = {
    "novant": {
        "name": "Novant Health",
        "patient_portal": "MyChart (Epic)",
        "lab_partner": "Labcorp",
        "primary_source": LabDataSource.MYCHART,
        "fallback_source": LabDataSource.LABCORP,
        "fhir_base_url": "https://epicproxy-np.et1277.epichosted.com/FHIR/api/FHIR/R4",  # placeholder
        "mychart_app_id": "",  # SMART on FHIR client ID — register with Novant/Epic
        "notes": "Novant patients view Labcorp results inside MyChart. Preferred path: Epic FHIR.",
    },
    "atrium": {
        "name": "Atrium Health",
        "patient_portal": "MyChart (Epic)",
        "lab_partner": "Labcorp",
        "primary_source": LabDataSource.MYCHART,
        "fallback_source": LabDataSource.LABCORP,
        "fhir_base_url": "",  # Atrium Epic instance — TBD
        "mychart_app_id": "",
        "notes": "Atrium Health (Advocate) uses Epic MyChart for patient access.",
    },
    "cone_health": {
        "name": "Cone Health",
        "patient_portal": "MyChart (Epic)",
        "lab_partner": "Labcorp",
        "primary_source": LabDataSource.MYCHART,
        "fallback_source": LabDataSource.LABCORP,
        "fhir_base_url": "",
        "mychart_app_id": "",
        "notes": "Cone Health patients access labs via MyChart.",
    },
    "labcorp_ondemand": {
        "name": "Labcorp OnDemand",
        "patient_portal": "Labcorp Patient Portal",
        "lab_partner": "Labcorp",
        "primary_source": LabDataSource.LABCORP,
        "fallback_source": None,
        "fhir_base_url": None,
        "mychart_app_id": None,
        "notes": "Direct-to-consumer; no hospital EMR.",
    },
}


def get_integration(health_system_id: str) -> Optional[Dict[str, Any]]:
    return HEALTH_SYSTEM_INTEGRATIONS.get(health_system_id)


def resolve_lab_source(health_system_id: str, mychart_connected: bool = False) -> LabDataSource:
    """
    Pick the active lab data source for a patient session.

    Novant example:
      - Patient logs in via MyChart SSO → use MYCHART (FHIR)
      - Patient logs in via NutriAI direct → fallback to LABCORP if linked
    """
    integration = get_integration(health_system_id)
    if not integration:
        return LabDataSource.LABCORP

    primary = integration["primary_source"]
    if primary == LabDataSource.MYCHART and mychart_connected:
        return LabDataSource.MYCHART

    fallback = integration.get("fallback_source")
    return fallback or primary


def list_health_systems() -> List[Dict[str, Any]]:
    return [
        {
            "id": key,
            "name": val["name"],
            "patient_portal": val["patient_portal"],
            "lab_partner": val["lab_partner"],
            "primary_source": val["primary_source"].value,
            "integration_path": _describe_path(val),
        }
        for key, val in HEALTH_SYSTEM_INTEGRATIONS.items()
    ]


def _describe_path(integration: Dict[str, Any]) -> str:
    if integration["primary_source"] == LabDataSource.MYCHART:
        return (
            f"Patient → {integration['patient_portal']} → FHIR API → NutriAI "
            f"(labs performed by {integration['lab_partner']})"
        )
    return f"Patient → {integration['lab_partner']} Portal → NutriAI"
