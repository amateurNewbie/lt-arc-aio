from enum import StrEnum


class CostCategoryScope(StrEnum):
    PROJECT = "PROJECT"
    COMPANY = "COMPANY"


class EmployeeStatus(StrEnum):
    ACTIVE = "ACTIVE"
    ON_LEAVE = "ON_LEAVE"


class GrantScopeType(StrEnum):
    ALL = "ALL"
    PROJECTS = "PROJECTS"


class LeadStatus(StrEnum):
    """FR-2.2 — Mới → Đang tư vấn → Đã báo giá → Đã chốt | Từ chối."""

    NEW = "NEW"
    CONSULTING = "CONSULTING"
    QUOTED = "QUOTED"
    CONVERTED = "CONVERTED"
    REJECTED = "REJECTED"


class ProjectCategory(StrEnum):
    DESIGN = "DESIGN"
    CONSTRUCTION = "CONSTRUCTION"
    TURNKEY = "TURNKEY"


class ProjectStatus(StrEnum):
    PLANNING = "PLANNING"
    IN_PROGRESS = "IN_PROGRESS"
    AWAITING_FEEDBACK = "AWAITING_FEEDBACK"
    COMPLETED = "COMPLETED"


class TaskPriority(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class TaskStatus(StrEnum):
    """FR-5.4 — cột Kanban: Cần làm / Đang làm / Đã hoàn thành."""

    TODO = "TODO"
    DOING = "DOING"
    DONE = "DONE"


class WorkItemStatus(StrEnum):
    NOT_STARTED = "NOT_STARTED"
    IN_PROGRESS = "IN_PROGRESS"
    DONE = "DONE"
