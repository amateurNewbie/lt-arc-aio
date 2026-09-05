from uuid import UUID

from sqlmodel import SQLModel


class AllowanceInput(SQLModel):
    name: str
    amount: int
    taxable: bool = True
    tax_free_cap: int | None = None


class PayProfileCreate(SQLModel):
    role_title: str
    daily_rate: int
    allowances: list[AllowanceInput] = []


class PayProfileUpdate(SQLModel):
    daily_rate: int | None = None
    allowances: list[AllowanceInput] | None = None
    active: bool | None = None


class PayProfileRead(SQLModel):
    id: UUID
    role_title: str
    daily_rate: int
    allowances: list[dict]
    active: bool


class EmployeePayOverrideUpdate(SQLModel):
    pay_profile_id: UUID | None = None
    daily_rate_override: int | None = None
    allowance_overrides: list[AllowanceInput] | None = None
