from fastapi import APIRouter

from app.api.v1 import (
    activities,
    auth,
    budget,
    contracts,
    cost_categories,
    departments,
    employees,
    files,
    funds,
    leads,
    notifications,
    overhead,
    pay_profiles,
    payables,
    payments,
    payroll,
    project_costs,
    projects,
    receivables,
    reports,
    settings,
    tasks,
    users,
    work_items,
    workdays,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(departments.router)
api_router.include_router(employees.router)
api_router.include_router(leads.router)
api_router.include_router(projects.router)
api_router.include_router(tasks.router)
api_router.include_router(work_items.router)
api_router.include_router(activities.router)
api_router.include_router(cost_categories.router)
api_router.include_router(budget.router)
api_router.include_router(project_costs.router)
api_router.include_router(contracts.router)
api_router.include_router(receivables.router)
api_router.include_router(payables.router)
api_router.include_router(funds.router)
api_router.include_router(overhead.router)
api_router.include_router(reports.router)
api_router.include_router(payments.router)
api_router.include_router(pay_profiles.router)
api_router.include_router(workdays.router)
api_router.include_router(payroll.router)
api_router.include_router(files.router)
api_router.include_router(notifications.router)
api_router.include_router(settings.router)
