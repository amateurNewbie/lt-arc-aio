"""Import every table model so `SQLModel.metadata` is fully populated before
Alembic autogenerate or `create_all` runs. See `sqlmodel-fastapi` skill."""

from sqlmodel import SQLModel

from app.models.activity import Activity  # noqa: F401
from app.models.budget import BudgetEstimate, BudgetEstimateLine  # noqa: F401
from app.models.company_settings import CompanySettings  # noqa: F401
from app.models.contract import Contract, ContractMilestone  # noqa: F401
from app.models.cost_category import CostCategory  # noqa: F401
from app.models.department import Department  # noqa: F401
from app.models.employee import Employee  # noqa: F401
from app.models.file_asset import FileAsset  # noqa: F401
from app.models.fund import CashLedgerEntry, FundAccount  # noqa: F401
from app.models.lead import Lead  # noqa: F401
from app.models.lead_status_history import LeadStatusHistory  # noqa: F401
from app.models.notification import Notification  # noqa: F401
from app.models.overhead import OverheadAllocation, OverheadCost  # noqa: F401
from app.models.payable import Payable  # noqa: F401
from app.models.pay_profile import PayProfile  # noqa: F401
from app.models.payment import Payment  # noqa: F401
from app.models.payroll import PayrollRecord  # noqa: F401
from app.models.permission_grant import UserPermissionGrant  # noqa: F401
from app.models.project import Project, ProjectDepartmentHead  # noqa: F401
from app.models.project_cost import ProjectCost  # noqa: F401
from app.models.task import Task  # noqa: F401
from app.models.user import User  # noqa: F401
from app.models.work_item import WorkItem  # noqa: F401
from app.models.workdays import MonthlyWorkDays  # noqa: F401

metadata = SQLModel.metadata
