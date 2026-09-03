from fastapi import APIRouter

from app.api.v1 import activities, auth, departments, employees, leads, projects, tasks, users, work_items

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
