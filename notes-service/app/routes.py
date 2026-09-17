from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas, auth
from app.database import get_db

router = APIRouter()


@router.get("/notes", response_model=list[schemas.NoteOut])
def list_notes(
    db: Session = Depends(get_db),
    user_id: int = Depends(auth.get_current_user_id),
):
    return (
        db.query(models.Note)
        .filter(models.Note.owner_id == user_id)
        .order_by(models.Note.created_at.desc())
        .all()
    )


@router.post("/notes", response_model=schemas.NoteOut, status_code=201)
def create_note(
    payload: schemas.NoteCreate,
    db: Session = Depends(get_db),
    user_id: int = Depends(auth.get_current_user_id),
):
    note = models.Note(title=payload.title, content=payload.content, owner_id=user_id)
    db.add(note)
    db.commit()
    db.refresh(note)
    return note


@router.get("/notes/{note_id}", response_model=schemas.NoteOut)
def get_note(
    note_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(auth.get_current_user_id),
):
    return _get_owned_note_or_404(note_id, db, user_id)


@router.put("/notes/{note_id}", response_model=schemas.NoteOut)
def update_note(
    note_id: int,
    payload: schemas.NoteUpdate,
    db: Session = Depends(get_db),
    user_id: int = Depends(auth.get_current_user_id),
):
    note = _get_owned_note_or_404(note_id, db, user_id)
    note.title = payload.title
    note.content = payload.content
    db.commit()
    db.refresh(note)
    return note


@router.delete("/notes/{note_id}", status_code=204)
def delete_note(
    note_id: int,
    db: Session = Depends(get_db),
    user_id: int = Depends(auth.get_current_user_id),
):
    note = _get_owned_note_or_404(note_id, db, user_id)
    db.delete(note)
    db.commit()


def _get_owned_note_or_404(note_id: int, db: Session, user_id: int) -> models.Note:
    note = (
        db.query(models.Note)
        .filter(models.Note.id == note_id, models.Note.owner_id == user_id)
        .first()
    )
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note
