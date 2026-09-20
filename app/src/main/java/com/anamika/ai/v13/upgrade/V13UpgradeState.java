package com.anamika.ai.v13.upgrade;

/** Single source of truth for the V13 phone-local self-upgrade pipeline. */
public enum V13UpgradeState {
    IDLE,
    SNAPSHOT,
    PLAN,
    PATCH,
    VALIDATE,
    BUILD,
    SIGN,
    VERIFY,
    OWNER_APPROVAL,
    INSTALL_REQUESTED,
    HEALTH_CHECK,
    STABLE,
    REJECTED,
    RECOVERY_REQUIRED
}
