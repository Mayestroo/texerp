# TexERP Domain

TexERP digitizes production approval and payroll for a single textile factory per tenant while preserving strict tenant isolation.

## Language

**Tenant**:
A textile factory with one isolated TexERP data space.
_Avoid_: Organization, account, customer

**User**:
A person identified by one globally unique phone number who belongs to exactly one Tenant in the MVP.
_Avoid_: Account, member

**Production Entry**:
A worker's financial source record stating which operation they performed, in what quantity, and on which work date.
_Avoid_: Production record, submission

**Foreman Assignment**:
The time-bounded relationship identifying the foreman responsible for a worker.
_Avoid_: Team membership, worker assignment
