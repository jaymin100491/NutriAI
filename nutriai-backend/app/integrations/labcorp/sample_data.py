"""
Real Labcorp sample data from patient portal API.
List summaries match production eLabCorp format; details include analyte values.
"""
from __future__ import annotations

from typing import Any, Dict, List

# Patient portal list response (as returned by hospital EMR integrations)
LABCORP_RESULT_SUMMARIES: List[Dict[str, Any]] = [
    {
        "testCodes": [{"testCode": "001818", "testName": "Glucose, Plasma", "resultCodes": [{"resultCode": "001818", "resultName": "Glucose, Plasma"}]}],
        "id": 778655,
        "accountName": "EAST PENN MEDICAL PRACTICE INC",
        "orderingProviderName": "B ADAMS",
        "dateOfService": "2026-06-15T09:18:00.000Z",
        "orderedDate": "2026-06-15T13:26:00.000Z",
        "reportDate": "2026-06-28T00:45:00.000Z",
        "dashboardCategory": "new",
        "weHealthEligible": False,
        "pid": 141756,
        "patientName": "Nate QATest",
        "isDetailAvailable": True,
        "hasMinimumDataForPdfRetrieval": True,
    },
    {
        "testCodes": [{"testCode": "001818", "testName": "Glucose, Plasma", "resultCodes": [{"resultCode": "001818", "resultName": "Glucose, Plasma"}]}],
        "id": 778075,
        "accountName": "LCA - eLabCorp Account #2 - MB",
        "orderingProviderName": "No Provider Given",
        "dateOfService": "2026-06-11T00:00:00.000Z",
        "orderedDate": "2026-06-11T14:27:00.000Z",
        "reportDate": "2026-06-11T14:28:00.000Z",
        "dashboardCategory": "recent",
        "weHealthEligible": False,
        "pid": 141756,
        "patientName": "Nate QATest",
        "isDetailAvailable": True,
        "hasMinimumDataForPdfRetrieval": True,
    },
    {
        "testCodes": [{"testCode": "139900", "testName": "SARS-CoV-2, NAA", "resultCodes": [{"resultCode": "139901", "resultName": "SARS-CoV-2, NAA"}]}],
        "id": 778077,
        "accountName": "LCA - eLabCorp Account #2 - MB",
        "orderingProviderName": "No Provider Given",
        "dateOfService": "2026-06-11T00:00:00.000Z",
        "orderedDate": "2026-06-11T14:35:00.000Z",
        "reportDate": "2026-06-11T14:37:00.000Z",
        "dashboardCategory": "recent",
        "weHealthEligible": False,
        "pid": 141756,
        "patientName": "Nate QATest",
        "isDetailAvailable": True,
        "hasMinimumDataForPdfRetrieval": True,
    },
    {
        "testCodes": [
            {"testCode": "001198", "testName": "Sodium", "resultCodes": [{"resultCode": "001198", "resultName": "Sodium"}]},
            {"testCode": "001818", "testName": "Glucose, Plasma", "resultCodes": [{"resultCode": "001818", "resultName": "Glucose, Plasma"}]},
        ],
        "id": 769386,
        "accountName": "LCA - eLabCorp Account #2 - MB",
        "orderingProviderName": "P PHILIP",
        "dateOfService": "2025-09-22T12:00:00.000Z",
        "orderedDate": "2025-09-22T20:00:00.000Z",
        "reportDate": "2025-09-22T20:16:00.000Z",
        "dashboardCategory": "recently_viewed",
        "weHealthEligible": False,
        "pid": 141756,
        "patientName": "Nate QATest",
        "isDetailAvailable": True,
        "hasMinimumDataForPdfRetrieval": True,
    },
    {
        "testCodes": [{"testCode": "001818", "testName": "Glucose, Plasma", "resultCodes": [{"resultCode": "001818", "resultName": "Glucose, Plasma"}]}],
        "id": 769385,
        "accountName": "LCA - eLabCorp Account #2 - MB",
        "orderingProviderName": "A ASHWINDR",
        "dateOfService": "2025-09-22T12:00:00.000Z",
        "orderedDate": "2025-09-22T19:07:00.000Z",
        "reportDate": "2025-09-22T19:14:00.000Z",
        "dashboardCategory": "recently_viewed",
        "weHealthEligible": False,
        "pid": 141756,
        "patientName": "Nate QATest",
        "isDetailAvailable": True,
        "hasMinimumDataForPdfRetrieval": True,
    },
    {
        "testCodes": [
            {"testCode": "070140", "testName": "Vitamin E", "resultCodes": [
                {"resultCode": "070141", "resultName": "Vitamin E(Alpha Tocopherol)"},
                {"resultCode": "070142", "resultName": "Vitamin E(Gamma Tocopherol)"},
            ]},
            {"testCode": "706994", "testName": "Homocyst(e)ine", "resultCodes": [{"resultCode": "707009", "resultName": "Homocyst(e)ine"}]},
        ],
        "id": 768287,
        "accountName": "Labcorp OnDemand",
        "orderingProviderName": "K RUDD",
        "dateOfService": "2025-08-07T13:52:00.000Z",
        "orderedDate": "2025-08-07T17:52:00.000Z",
        "reportDate": "2025-08-07T17:53:00.000Z",
        "dashboardCategory": "recently_viewed",
        "weHealthEligible": False,
        "pid": 141756,
        "patientName": "Nate QATest",
        "isDetailAvailable": True,
        "hasMinimumDataForPdfRetrieval": True,
    },
]

# Detail payloads — analyte values (simulates GET /results/{id}/detail)
LABCORP_RESULT_DETAILS: Dict[int, Dict[str, Any]] = {
    778655: {
        "id": 778655, "pid": 141756, "patientName": "Nate QATest",
        "dateOfService": "2026-06-15T09:18:00.000Z", "reportDate": "2026-06-28T00:45:00.000Z",
        "orderingProviderName": "B ADAMS", "accountName": "EAST PENN MEDICAL PRACTICE INC",
        "results": [
            {"resultCode": "001818", "resultName": "Glucose, Plasma", "testCode": "001818",
             "value": "118", "unit": "mg/dL", "referenceRange": "65-99", "abnormalFlag": "H"},
        ],
    },
    778075: {
        "id": 778075, "pid": 141756, "patientName": "Nate QATest",
        "dateOfService": "2026-06-11T00:00:00.000Z", "reportDate": "2026-06-11T14:28:00.000Z",
        "orderingProviderName": "No Provider Given", "accountName": "LCA - eLabCorp Account #2 - MB",
        "results": [
            {"resultCode": "001818", "resultName": "Glucose, Plasma", "testCode": "001818",
             "value": "94", "unit": "mg/dL", "referenceRange": "65-99", "abnormalFlag": "N"},
        ],
    },
    778077: {
        "id": 778077, "pid": 141756, "patientName": "Nate QATest",
        "dateOfService": "2026-06-11T00:00:00.000Z", "reportDate": "2026-06-11T14:37:00.000Z",
        "orderingProviderName": "No Provider Given", "accountName": "LCA - eLabCorp Account #2 - MB",
        "results": [
            {"resultCode": "139901", "resultName": "SARS-CoV-2, NAA", "testCode": "139900",
             "value": "Not Detected", "unit": "", "referenceRange": "Not Detected", "abnormalFlag": "N"},
        ],
    },
    769386: {
        "id": 769386, "pid": 141756, "patientName": "Nate QATest",
        "dateOfService": "2025-09-22T12:00:00.000Z", "reportDate": "2025-09-22T20:16:00.000Z",
        "orderingProviderName": "P PHILIP", "accountName": "LCA - eLabCorp Account #2 - MB",
        "results": [
            {"resultCode": "001198", "resultName": "Sodium", "testCode": "001198",
             "value": "140", "unit": "mmol/L", "referenceRange": "134-144", "abnormalFlag": "N"},
            {"resultCode": "001818", "resultName": "Glucose, Plasma", "testCode": "001818",
             "value": "108", "unit": "mg/dL", "referenceRange": "65-99", "abnormalFlag": "H"},
        ],
    },
    769385: {
        "id": 769385, "pid": 141756, "patientName": "Nate QATest",
        "dateOfService": "2025-09-22T12:00:00.000Z", "reportDate": "2025-09-22T19:14:00.000Z",
        "orderingProviderName": "A ASHWINDR", "accountName": "LCA - eLabCorp Account #2 - MB",
        "results": [
            {"resultCode": "001818", "resultName": "Glucose, Plasma", "testCode": "001818",
             "value": "112", "unit": "mg/dL", "referenceRange": "65-99", "abnormalFlag": "H"},
        ],
    },
    768287: {
        "id": 768287, "pid": 141756, "patientName": "Nate QATest",
        "dateOfService": "2025-08-07T13:52:00.000Z", "reportDate": "2025-08-07T17:53:00.000Z",
        "orderingProviderName": "K RUDD", "accountName": "Labcorp OnDemand",
        "results": [
            {"resultCode": "070141", "resultName": "Vitamin E(Alpha Tocopherol)", "testCode": "070140",
             "value": "8.2", "unit": "mg/L", "referenceRange": "5.5-18.4", "abnormalFlag": "N"},
            {"resultCode": "070142", "resultName": "Vitamin E(Gamma Tocopherol)", "testCode": "070140",
             "value": "1.8", "unit": "mg/L", "referenceRange": "0.5-5.0", "abnormalFlag": "N"},
            {"resultCode": "707009", "resultName": "Homocyst(e)ine", "testCode": "706994",
             "value": "14.8", "unit": "umol/L", "referenceRange": "<10.4", "abnormalFlag": "H"},
        ],
    },
}

# Map NutriAI demo user -> Labcorp patient ID
USER_LABCORP_PID_MAP = {
    1: 141756,  # Test user gets Nate QATest Labcorp data
    2: 141756,
}

# Health systems that can integrate (enterprise white-label)
SUPPORTED_HEALTH_SYSTEMS = {
    "atrium": {"name": "Atrium Health", "labcorp_account_prefix": "ATRIUM"},
    "novant": {"name": "Novant Health", "labcorp_account_prefix": "NOVANT"},
    "cone_health": {"name": "Cone Health", "labcorp_account_prefix": "CONE"},
    "labcorp_ondemand": {"name": "Labcorp OnDemand", "labcorp_account_prefix": "LCA"},
}
