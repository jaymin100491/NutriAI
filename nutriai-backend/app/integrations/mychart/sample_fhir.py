"""
Sample FHIR R4 bundles mirroring Novant MyChart lab results.
Derived from real Labcorp data — same clinical values, Epic wire format.
"""
from __future__ import annotations

from typing import Any, Dict, List

# Novant MyChart patient FHIR ID (would come from OAuth Patient resource)
NOVANT_DEMO_PATIENT_FHIR_ID = "ePatient-141756"

MOCK_FHIR_BUNDLES: List[Dict[str, Any]] = [
    {
        "patient_id": NOVANT_DEMO_PATIENT_FHIR_ID,
        "report_id": "dr-778655",
        "labcorp_result_id": 778655,
        "resourceType": "DiagnosticReport",
        "status": "final",
        "code": {"coding": [{"system": "http://labcorp.com/test", "code": "001818", "display": "Glucose, Plasma"}]},
        "subject": {"reference": f"Patient/{NOVANT_DEMO_PATIENT_FHIR_ID}", "display": "Nate QATest"},
        "effectiveDateTime": "2026-06-15T09:18:00Z",
        "issued": "2026-06-28T00:45:00Z",
        "performer": [{"display": "Labcorp"}],
        "resultsInterpreter": [{"display": "B ADAMS"}],
        "basedOn": [{"display": "EAST PENN MEDICAL PRACTICE INC"}],
        "conclusion": "Glucose elevated — dietary management recommended",
    },
    {
        "patient_id": NOVANT_DEMO_PATIENT_FHIR_ID,
        "report_id": "dr-768287",
        "labcorp_result_id": 768287,
        "resourceType": "DiagnosticReport",
        "status": "final",
        "code": {"coding": [{"system": "http://labcorp.com/test", "code": "706994", "display": "Homocyst(e)ine Panel"}]},
        "subject": {"reference": f"Patient/{NOVANT_DEMO_PATIENT_FHIR_ID}", "display": "Nate QATest"},
        "effectiveDateTime": "2025-08-07T13:52:00Z",
        "issued": "2025-08-07T17:53:00Z",
        "performer": [{"display": "Labcorp"}],
        "resultsInterpreter": [{"display": "K RUDD"}],
        "basedOn": [{"display": "Labcorp OnDemand"}],
    },
]

MOCK_OBSERVATIONS: Dict[str, List[Dict[str, Any]]] = {
    "dr-778655": [
        {
            "resourceType": "Observation",
            "status": "final",
            "code": {"coding": [{"system": "http://loinc.org", "code": "2345-7", "display": "Glucose, Plasma"}]},
            "valueQuantity": {"value": 118, "unit": "mg/dL", "system": "http://unitsofmeasure.org"},
            "referenceRange": [{"text": "65-99"}],
            "interpretation": [{"coding": [{"code": "H", "display": "High"}]}],
        },
    ],
    "dr-768287": [
        {
            "resourceType": "Observation",
            "status": "final",
            "code": {"coding": [{"system": "http://loinc.org", "code": "46207-3", "display": "Homocyst(e)ine"}]},
            "valueQuantity": {"value": 14.8, "unit": "umol/L"},
            "referenceRange": [{"text": "<10.4"}],
            "interpretation": [{"coding": [{"code": "H"}]}],
        },
    ],
}

# Map NutriAI demo user → Novant MyChart FHIR patient ID
USER_MYCHART_PATIENT_MAP = {
    1: NOVANT_DEMO_PATIENT_FHIR_ID,
    2: NOVANT_DEMO_PATIENT_FHIR_ID,
}
