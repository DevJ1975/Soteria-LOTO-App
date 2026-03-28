// ============================================================
// Phase 9 — AI Prompt Layer
// All prompts for LOTO procedure drafting, translation, and review
// ============================================================

export const LOTO_SYSTEM_PROMPT = `You are a highly specialized industrial safety AI assistant for Lockout/Tagout (LOTO) procedure documentation. You help safety professionals create machine-specific energy control procedures aligned with Cal/OSHA Title 8 Section 3314 requirements.

CRITICAL RULES:
1. You DRAFT procedures for human review only — you are never the approver or final authority
2. You must flag every assumption you make
3. You must flag every piece of information that is missing or unclear
4. You must flag any situation where the procedure may be incomplete
5. You are NOT providing legal advice — you are generating a procedure draft for EHS professional review
6. Never fabricate specific voltage levels, pressure values, or physical locations — only use what was provided
7. Always recommend verification of isolation before work begins
8. Flag when stored energy controls appear incomplete

FACILITY CONTEXT:
- These procedures are used in manufacturing environments
- Users are maintenance technicians and EHS professionals
- Procedures will be printed on laminated placards and posted on equipment
- Procedures must be clear enough for qualified maintenance personnel to follow without additional instruction

OUTPUT FORMAT:
Always respond with valid JSON matching the provided schema exactly. Never include explanatory text outside the JSON.`;

export const LOTO_DRAFT_PROMPT = (input: Record<string, unknown>): string => `
Generate a complete LOTO procedure draft for the following equipment.

EQUIPMENT INFORMATION:
${JSON.stringify(input, null, 2)}

Generate the complete LOTO procedure following this exact JSON schema:

{
  "machineSummary": "string — brief equipment description for the placard header",

  "energySources": [
    {
      "type": "electrical|pneumatic|hydraulic|gravity|spring_tension|steam|gas|thermal|chemical|vacuum|stored_mechanical|kinetic|other",
      "description": "string — human-readable description",
      "location": "string or null if unknown",
      "magnitude": "string — voltage/pressure/etc. or null if unknown",
      "aiGenerated": true
    }
  ],

  "isolationPoints": [
    {
      "sequence": 1,
      "description": "string — what to isolate and how",
      "deviceType": "circuit_breaker_lockout|gate_valve_lockout|ball_valve_lockout|plug_lockout|pneumatic_lockout|hydraulic_lockout|cable_lockout|lockout_hasp|danger_tag|other",
      "location": "string or null if unknown",
      "normalState": "string e.g. CLOSED, ENERGIZED, ON",
      "isolatedState": "string e.g. OPEN, DE-ENERGIZED, OFF",
      "aiGenerated": true
    }
  ],

  "shutdownSteps": [
    { "sequence": 1, "instruction": "string", "warnings": [], "aiGenerated": true }
  ],

  "isolationSteps": [
    { "sequence": 1, "instruction": "string", "warnings": [], "aiGenerated": true }
  ],

  "lockoutSteps": [
    { "sequence": 1, "instruction": "string", "warnings": [], "aiGenerated": true }
  ],

  "storedEnergySteps": [
    { "sequence": 1, "instruction": "string", "warnings": [], "aiGenerated": true }
  ],

  "verificationSteps": [
    { "sequence": 1, "instruction": "string", "warnings": [], "aiGenerated": true }
  ],

  "restartSteps": [
    { "sequence": 1, "instruction": "string", "warnings": [], "aiGenerated": true }
  ],

  "warnings": ["string array of safety warnings"],
  "specialCautions": ["string array of special cautions"],
  "requiredPPE": ["string array of PPE requirements"],

  "assumptions": [
    "string — each assumption made during drafting that must be verified by the authorized employee"
  ],

  "missingInfoFlags": [
    "string — each piece of information that was missing and must be confirmed before approval"
  ],

  "reviewRequired": [
    "string — each item that specifically requires human review before approval"
  ],

  "confidenceScore": 0.0,
  "confidenceNotes": "string — overall quality assessment of this draft"
}

STEP QUALITY REQUIREMENTS:
- Shutdown steps must describe how to bring the equipment to a safe stop
- Isolation steps must name specific isolation devices (disconnect number, valve tag, etc.) when known
- Lockout steps must instruct applying a personal lock to each isolation device
- Stored energy steps must address ALL forms of stored energy (capacitors, springs, elevated components, pressurized lines, etc.)
- Verification steps must include: attempt to start/operate equipment to confirm zero energy state
- Return to service steps must include: notify affected personnel before restart

FLAG these situations explicitly in missingInfoFlags:
- Missing disconnect/breaker identification numbers
- Missing pressure or voltage values when energy sources are present
- Missing stored energy controls for any stored energy type
- Missing verification method for any energy source
- Any isolation point without a named device type

Set confidenceScore between 0.0 (very low confidence) and 1.0 (high confidence).
If critical information is missing, confidenceScore should be 0.4 or lower.`;

export const TRANSLATION_PROMPT = (englishContent: Record<string, unknown>): string => `
Translate the following LOTO procedure content from English to Spanish (Latin American Spanish, suitable for manufacturing environments in California with a predominantly Mexican workforce).

TRANSLATION RULES:
1. Maintain all technical accuracy — do not simplify safety instructions
2. Use clear, direct imperative forms for procedure steps (e.g., "Apague el equipo" not "El equipo debe ser apagado")
3. Keep all numbers, codes, and equipment IDs in their original form
4. Use consistent terminology throughout — translate the same English term the same way every time
5. For terms with no direct Spanish equivalent, provide the English term in parentheses after the Spanish
6. Flag any terms where you are uncertain about the correct technical translation

CONTENT TO TRANSLATE:
${JSON.stringify(englishContent, null, 2)}

Return JSON with these fields translated:
{
  "machineSummary": "translated string",
  "procedureStepsTranslated": [
    { "id": "step id", "instruction": "translated instruction", "warnings": ["translated warnings"] }
  ],
  "energySourcesTranslated": [
    { "id": "source id", "description": "translated description" }
  ],
  "isolationPointsTranslated": [
    { "id": "point id", "description": "translated description" }
  ],
  "warningsTranslated": ["translated warning strings"],
  "specialCautionsTranslated": ["translated caution strings"],
  "requiredPPETranslated": ["translated PPE strings"],
  "translationNotes": ["notes about uncertain translations"],
  "confidenceScore": 0.0
}`;

export const REVIEW_VALIDATION_PROMPT = (placardContent: Record<string, unknown>): string => `
Review the following LOTO procedure draft for completeness and quality against Cal/OSHA Title 8 Section 3314 requirements.

PROCEDURE TO REVIEW:
${JSON.stringify(placardContent, null, 2)}

Analyze and return:
{
  "overallAssessment": "PASS|NEEDS_REVISION|CRITICAL_GAPS",
  "criticalGaps": [
    "string — critical issue that must be resolved before approval"
  ],
  "recommendations": [
    "string — improvement recommendation (not blocking)"
  ],
  "complianceChecks": {
    "hasShutdownSteps": true|false,
    "hasIsolationForEachEnergySource": true|false,
    "hasLockoutInstructions": true|false,
    "hasStoredEnergyRelease": true|false,
    "hasZeroEnergyVerification": true|false,
    "hasReturnToServiceSteps": true|false,
    "hasEquipmentIdentification": true|false,
    "hasMachineLocation": true|false
  },
  "missingElements": ["list of missing procedure elements"],
  "confidenceScore": 0.0,
  "reviewNotes": "string — overall notes for the human reviewer"
}`;
