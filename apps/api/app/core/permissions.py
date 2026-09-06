from enum import StrEnum


class Role(StrEnum):
    ADMIN = "ADMIN"
    DIRECTOR = "DIRECTOR"
    DEPARTMENT_HEAD = "DEPARTMENT_HEAD"
    EMPLOYEE = "EMPLOYEE"


class PermissionGroup(StrEnum):
    """FR-1.7 — 6 nhóm quyền bổ sung cấp theo từng người dùng."""

    PROJECT_CASHBOOK = "PROJECT_CASHBOOK"
    OVERHEAD_ALLOCATE = "OVERHEAD_ALLOCATE"
    FUNDS = "FUNDS"
    DEBTS = "DEBTS"
    CONTRACTS_COLLECT = "CONTRACTS_COLLECT"
    WORKDAYS_ENTRY = "WORKDAYS_ENTRY"


# Seed / fallback khi bảng rolepermissiondefault chưa có dòng:
# Admin/Director toàn quyền 6 nhóm (RBAC matrix SRS §2.6).
ROLES_WITH_ALL_GRANTS_BY_DEFAULT = {Role.ADMIN, Role.DIRECTOR}
