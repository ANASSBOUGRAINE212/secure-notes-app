from sqlalchemy import Column, Integer, String, Text, DateTime
from sqlalchemy.sql import func
from app.database import Base


class Note(Base):
    __tablename__ = "notes"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)

    # this used to be a ForeignKey to users.id, but users now live in a
    # completely separate database (owned by auth-service). cross-database
    # foreign keys aren't a thing in Postgres, so this is just a plain int —
    # the actual identity check happens via the verified JWT, not the DB.
    owner_id = Column(Integer, nullable=False, index=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
