"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import {
  Alert,
  Button,
  CheckboxField,
  DataTable,
  EmptyState,
  SelectField,
  TextField,
} from "@/design/ui";
import { pageTranslation } from "@/institutes/site-pages";
import type {
  ClassCandidate,
  ClassRoom,
  TeacherChoice,
} from "@/server/classes";

type Copy = typeof common.staffClasses;

export function ClassBoard({
  locale,
  copy,
  isAdmin,
  canCreateStudents,
  classes,
  students,
  teachers,
}: {
  locale: Locale;
  copy: Copy;
  isAdmin: boolean;
  canCreateStudents: boolean;
  classes: ClassRoom[];
  students: ClassCandidate[];
  teachers: TeacherChoice[];
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [warning, setWarning] = useState("");
  const [created, setCreated] = useState<{
    username: string;
    password: string;
  } | null>(null);

  function nameOf(value: ClassRoom["name"]) {
    return pageTranslation(value, locale)?.text ?? "";
  }

  async function send(path: string, body: Record<string, unknown>) {
    setBusy(true);
    setMessage("");
    setWarning("");
    const response = await authRequest(path, body);
    const result = (await response.json().catch(() => null)) as {
      code?: string;
      username?: string;
      password?: string;
    } | null;
    setBusy(false);
    if (result?.username && result.password) {
      setCreated({ username: result.username, password: result.password });
      setMessage(copy.created);
      router.refresh();
      return;
    }
    if (result?.code === "saved") setMessage(copy.saved);
    else if (result?.code === "added") setMessage(copy.added);
    else if (result?.code === "ended") setMessage(copy.ended);
    else if (result?.code === "left") setMessage(copy.left);
    else if (result?.code === "already_left") setWarning(copy.alreadyLeft);
    else if (result?.code === "reset") setMessage(copy.resetDone);
    else if (result?.code === "already_member") setWarning(copy.already);
    else if (result?.code === "denied") setWarning(copy.denied);
    else if (result?.code === "invalid") setWarning(copy.invalid);
    else {
      setWarning(copy.unavailable);
      return;
    }
    router.refresh();
  }

  function onSave(
    event: FormEvent<HTMLFormElement>,
    classId?: string,
    archived = false,
  ) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    void send("class", {
      action: "save",
      classId,
      nameUr: String(data.get("nameUr") ?? ""),
      nameEn: String(data.get("nameEn") ?? ""),
      yearLabel: String(data.get("year") ?? ""),
      archived,
    });
  }

  return (
    <>
      <section className="ui-card" aria-labelledby="new-class-title">
        <h2 id="new-class-title">{copy.newClass}</h2>
        <form className="ui-form" onSubmit={(event) => onSave(event)}>
          <TextField
            id="class-name-ur"
            name="nameUr"
            label={copy.nameUr}
            maxLength={80}
          />
          <TextField
            id="class-name-en"
            name="nameEn"
            label={copy.nameEn}
            maxLength={80}
          />
          <TextField
            id="class-year"
            name="year"
            label={copy.year}
            maxLength={40}
          />
          <Button type="submit" disabled={busy}>
            {busy ? copy.pending : copy.save}
          </Button>
        </form>
      </section>

      {canCreateStudents && (
        <section className="ui-card" aria-labelledby="new-student-title">
          <h2 id="new-student-title">{copy.createStudent}</h2>
          <form
            className="ui-form"
            onSubmit={(event) => {
              event.preventDefault();
              const data = new FormData(event.currentTarget);
              void send("student-account", {
                name: String(data.get("name") ?? ""),
                classId: String(data.get("classId") ?? ""),
                isOrphan: data.get("orphan") === "on",
              });
            }}
          >
            <TextField
              id="student-name"
              name="name"
              label={copy.studentName}
              required
              maxLength={120}
              autoComplete="off"
            />
            <SelectField
              id="student-class"
              name="classId"
              label={copy.heading}
              required
              defaultValue=""
            >
              <option value="">{copy.choose}</option>
              {classes
                .filter((room) => !room.archived && room.manage_students)
                .map((room) => (
                  <option key={room.id} value={room.id}>
                    {nameOf(room.name)}
                  </option>
                ))}
            </SelectField>
            <CheckboxField
              id="student-orphan"
              name="orphan"
              label={copy.orphan}
            />
            <Button type="submit" disabled={busy}>
              {busy ? copy.pending : copy.create}
            </Button>
          </form>
          {created && (
            <Alert tone="success">
              {copy.username}: <bdi>{created.username}</bdi>
              <br />
              {copy.password}: <bdi>{created.password}</bdi>
            </Alert>
          )}
        </section>
      )}

      {classes.length ? (
        classes.map((room) => {
          const inClass = new Set(
            room.students.map((student) => student.user_id),
          );
          const teaching = new Set(
            room.teachers.map((teacher) => teacher.user_id),
          );
          const studentChoices = students.filter(
            (student) => !inClass.has(student.user_id),
          );
          const teacherChoices = teachers.filter(
            (teacher) => !teaching.has(teacher.user_id),
          );
          return (
            <section
              className="ui-card"
              key={room.id}
              aria-labelledby={room.id}
            >
              <h2 id={room.id}>
                {nameOf(room.name)}
                {room.year_label ? (
                  <span>
                    {" "}
                    · <bdi>{room.year_label}</bdi>
                  </span>
                ) : null}
                {room.kind === "alumni" ? <span> · {copy.alumni}</span> : null}
                {room.archived ? <span> · {copy.archived}</span> : null}
              </h2>
              <h3>{copy.teachers}</h3>
              {room.teachers.length > 0 && (
                <DataTable
                  columns={[
                    { key: "name", label: copy.teachers },
                    { key: "action", label: copy.end },
                  ]}
                  rows={room.teachers.map((teacher) => ({
                    name: <bdi>{teacher.name}</bdi>,
                    action: room.manage_teachers ? (
                      <Button
                        variant="secondary"
                        disabled={busy}
                        onClick={() =>
                          void send("class", {
                            action: "member",
                            classId: room.id,
                            userId: teacher.user_id,
                            memberRole: "teacher",
                            change: "end",
                          })
                        }
                      >
                        {copy.end}
                      </Button>
                    ) : null,
                  }))}
                />
              )}
              {room.manage_teachers && (
                <form
                  className="ui-form"
                  onSubmit={(event) => {
                    event.preventDefault();
                    const data = new FormData(event.currentTarget);
                    void send("class", {
                      action: "member",
                      classId: room.id,
                      userId: String(data.get("userId") ?? ""),
                      memberRole: "teacher",
                      change: "add",
                    });
                  }}
                >
                  <SelectField
                    id={`add-teacher-${room.id}`}
                    name="userId"
                    label={copy.addTeacher}
                    required
                    defaultValue=""
                  >
                    <option value="">{copy.choose}</option>
                    {teacherChoices.map((teacher) => (
                      <option key={teacher.user_id} value={teacher.user_id}>
                        {teacher.name}
                      </option>
                    ))}
                  </SelectField>
                  <Button type="submit" variant="secondary" disabled={busy}>
                    {copy.add}
                  </Button>
                </form>
              )}
              <h3>{copy.students}</h3>
              {room.students.length ? (
                <DataTable
                  columns={[
                    { key: "persona", label: copy.persona },
                    { key: "real", label: copy.realName },
                    { key: "action", label: copy.end },
                  ]}
                  rows={room.students.map((student) => ({
                    persona: <bdi>{student.persona ?? "—"}</bdi>,
                    real: <bdi>{student.real_name ?? copy.hiddenName}</bdi>,
                    action: room.manage_students ? (
                      <span className="hub-actions">
                        {room.kind !== "alumni" && (
                          <Button
                            variant="secondary"
                            disabled={busy}
                            onClick={() =>
                              void send("class", {
                                action: "member",
                                classId: room.id,
                                userId: student.user_id,
                                memberRole: "student",
                                change: "end",
                              })
                            }
                          >
                            {copy.end}
                          </Button>
                        )}
                        <Button
                          variant="secondary"
                          disabled={busy}
                          onClick={() =>
                            void send("class", {
                              action: "reset",
                              userId: student.user_id,
                            })
                          }
                        >
                          {copy.resetName}
                        </Button>
                        {isAdmin &&
                          room.kind !== "alumni" &&
                          student.status !== "left" && (
                            <Button
                              variant="secondary"
                              disabled={busy}
                              onClick={() =>
                                void send("class", {
                                  action: "leave",
                                  userId: student.user_id,
                                })
                              }
                            >
                              {copy.markLeft}
                            </Button>
                          )}
                      </span>
                    ) : null,
                  }))}
                />
              ) : (
                <p>{copy.noStudents}</p>
              )}
              {room.manage_students && !room.archived && (
                <form
                  className="ui-form"
                  onSubmit={(event) => {
                    event.preventDefault();
                    const data = new FormData(event.currentTarget);
                    void send("class", {
                      action: "member",
                      classId: room.id,
                      userId: String(data.get("userId") ?? ""),
                      memberRole: "student",
                      change: "add",
                    });
                  }}
                >
                  <SelectField
                    id={`add-student-${room.id}`}
                    name="userId"
                    label={copy.addStudent}
                    required
                    defaultValue=""
                  >
                    <option value="">{copy.choose}</option>
                    {studentChoices.map((student) => (
                      <option key={student.user_id} value={student.user_id}>
                        {student.persona ??
                          student.real_name ??
                          student.user_id}
                      </option>
                    ))}
                  </SelectField>
                  <Button type="submit" variant="secondary" disabled={busy}>
                    {copy.add}
                  </Button>
                </form>
              )}
            </section>
          );
        })
      ) : (
        <EmptyState title={copy.noClasses}>{copy.intro}</EmptyState>
      )}
      {message && <Alert tone="success">{message}</Alert>}
      {warning && <Alert tone="danger">{warning}</Alert>}
    </>
  );
}
