"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
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
  canCreateStudents,
  classes,
  students,
  teachers,
}: {
  locale: Locale;
  copy: Copy;
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
      <section className="staff-panel" aria-labelledby="new-class-title">
        <h2 id="new-class-title">{copy.newClass}</h2>
        <form className="staff-fields" onSubmit={(event) => onSave(event)}>
          <label>
            {copy.nameUr}
            <input name="nameUr" maxLength={80} />
          </label>
          <label>
            {copy.nameEn}
            <input name="nameEn" maxLength={80} />
          </label>
          <label>
            {copy.year}
            <input name="year" maxLength={40} />
          </label>
          <button
            className="button button-primary"
            type="submit"
            disabled={busy}
          >
            {busy ? copy.pending : copy.save}
          </button>
        </form>
      </section>

      {canCreateStudents && (
        <section className="staff-panel" aria-labelledby="new-student-title">
          <h2 id="new-student-title">{copy.createStudent}</h2>
          <form
            className="staff-fields"
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
            <label>
              {copy.studentName}
              <input name="name" required maxLength={120} autoComplete="off" />
            </label>
            <label>
              {copy.heading}
              <select name="classId" required defaultValue="">
                <option value="">{copy.choose}</option>
                {classes
                  .filter((room) => !room.archived && room.manage_students)
                  .map((room) => (
                    <option key={room.id} value={room.id}>
                      {nameOf(room.name)}
                    </option>
                  ))}
              </select>
            </label>
            <label className="staff-span">
              <input name="orphan" type="checkbox" /> {copy.orphan}
            </label>
            <button
              className="button button-primary"
              type="submit"
              disabled={busy}
            >
              {busy ? copy.pending : copy.create}
            </button>
          </form>
          {created && (
            <p className="staff-note" role="status">
              {copy.username}: <bdi>{created.username}</bdi>
              <br />
              {copy.password}: <bdi>{created.password}</bdi>
            </p>
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
              className="staff-panel"
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
                {room.archived ? <span> · {copy.archived}</span> : null}
              </h2>
              <h3>{copy.teachers}</h3>
              <ul className="staff-rows">
                {room.teachers.map((teacher) => (
                  <li className="staff-row" key={teacher.user_id}>
                    <strong>
                      <bdi>{teacher.name}</bdi>
                    </strong>
                    {room.manage_teachers && (
                      <button
                        className="button button-outline"
                        type="button"
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
                      </button>
                    )}
                  </li>
                ))}
              </ul>
              {room.manage_teachers && (
                <form
                  className="staff-fields"
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
                  <label>
                    {copy.addTeacher}
                    <select name="userId" required defaultValue="">
                      <option value="">{copy.choose}</option>
                      {teacherChoices.map((teacher) => (
                        <option key={teacher.user_id} value={teacher.user_id}>
                          {teacher.name}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button
                    className="button button-outline"
                    type="submit"
                    disabled={busy}
                  >
                    {copy.add}
                  </button>
                </form>
              )}
              <h3>{copy.students}</h3>
              {room.students.length ? (
                <ul className="staff-rows">
                  {room.students.map((student) => (
                    <li className="staff-row" key={student.user_id}>
                      <dl>
                        <div>
                          <dt>{copy.persona}</dt>
                          <dd>
                            <bdi>{student.persona ?? "—"}</bdi>
                          </dd>
                        </div>
                        <div>
                          <dt>{copy.realName}</dt>
                          <dd>
                            <bdi>{student.real_name ?? copy.hiddenName}</bdi>
                          </dd>
                        </div>
                      </dl>
                      {room.manage_students && (
                        <button
                          className="button button-outline"
                          type="button"
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
                        </button>
                      )}
                    </li>
                  ))}
                </ul>
              ) : (
                <p>{copy.noStudents}</p>
              )}
              {room.manage_students && !room.archived && (
                <form
                  className="staff-fields"
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
                  <label>
                    {copy.addStudent}
                    <select name="userId" required defaultValue="">
                      <option value="">{copy.choose}</option>
                      {studentChoices.map((student) => (
                        <option key={student.user_id} value={student.user_id}>
                          {student.persona ??
                            student.real_name ??
                            student.user_id}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button
                    className="button button-outline"
                    type="submit"
                    disabled={busy}
                  >
                    {copy.add}
                  </button>
                </form>
              )}
            </section>
          );
        })
      ) : (
        <p>{copy.noClasses}</p>
      )}
      {message && (
        <p className="staff-success" role="status">
          {message}
        </p>
      )}
      {warning && (
        <p className="staff-warning" role="alert">
          {warning}
        </p>
      )}
    </>
  );
}
