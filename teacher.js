const labels = ['ก', 'ข', 'ค', 'ง', 'จ', 'ฉ'];

const $ = s => document.querySelector(s);

const C = window.EXAM_CONFIG;

const S = supabase.createClient(
    C.supabaseUrl,
    C.supabaseAnonKey
);

let questions = [];

let timer = null;

let teacherCountdownTimer = null;
let teacherQuestionEndsAt = null;


/* =========================================
   ESCAPE HTML
========================================= */

const esc = s =>
    String(s ?? '').replace(
        /[&<>"']/g,
        c => ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        }[c])
    );


/* =========================================
   SUPABASE RPC
========================================= */

async function rpc(
    name,
    args = {}
) {

    const {
        data,
        error
    } = await S.rpc(
        name,
        args
    );

    if (error) {
        throw error;
    }

    return data;
}


/* =========================================
   TEACHER TIMER
========================================= */

function formatTeacherTime(
    totalSeconds
) {

    const seconds =
        Math.max(
            0,
            Math.floor(
                Number(totalSeconds) || 0
            )
        );

    const minutes =
        Math.floor(
            seconds / 60
        );

    const secs =
        seconds % 60;

    return (
        String(minutes)
            .padStart(2, '0')
        +
        ':'
        +
        String(secs)
            .padStart(2, '0')
    );
}


function formatTeacherEndTime(
    date
) {

    if (
        !(date instanceof Date) ||
        Number.isNaN(
            date.getTime()
        )
    ) {

        return '--:--:--';
    }

    return date.toLocaleTimeString(
        'th-TH',
        {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: false
        }
    );
}


function stopTeacherCountdown() {

    if (
        teacherCountdownTimer
    ) {

        clearInterval(
            teacherCountdownTimer
        );

        teacherCountdownTimer =
            null;
    }

    teacherQuestionEndsAt =
        null;
}


function startTeacherCountdown(
    remainingSeconds
) {

    stopTeacherCountdown();


    const seconds =
        Math.max(
            0,
            Number(
                remainingSeconds
            ) || 0
        );


    teacherQuestionEndsAt =
        new Date(
            Date.now()
            +
            seconds * 1000
        );


    function updateTimer() {

        const timerBox =
            $('#teacherQuestionTimer');

        const timerText =
            $('#teacherTimerText');

        const endText =
            $('#teacherEndTime');


        if (
            !timerBox ||
            !timerText
        ) {

            stopTeacherCountdown();

            return;
        }


        const remaining =
            Math.max(
                0,
                Math.ceil(
                    (
                        teacherQuestionEndsAt.getTime()
                        -
                        Date.now()
                    )
                    /
                    1000
                )
            );


        timerText.textContent =
            formatTeacherTime(
                remaining
            );


        if (endText) {

            endText.textContent =
                formatTeacherEndTime(
                    teacherQuestionEndsAt
                );
        }


        timerBox.classList.toggle(
            'warning',
            remaining > 10 &&
            remaining <= 30
        );


        timerBox.classList.toggle(
            'danger',
            remaining <= 10
        );


        if (
            remaining <= 0
        ) {

            timerText.textContent =
                '00:00';

            timerBox.classList.add(
                'danger'
            );

            stopTeacherCountdown();
        }
    }


    updateTimer();


    teacherCountdownTimer =
        setInterval(
            updateTimer,
            1000
        );
}


/* =========================================
   LOGIN
========================================= */

$('#loginForm').onsubmit =
    async e => {

        e.preventDefault();

        $('#loginMsg').textContent =
            '';


        const {
            error
        } =
            await S.auth
                .signInWithPassword({
                    email:
                        $('#email').value,

                    password:
                        $('#password').value
                });


        if (
            error
        ) {

            $('#loginMsg').textContent =
                error.message;

            return;
        }


        await openApp();
    };


/* =========================================
   LOGOUT
========================================= */

$('#logout').onclick =
    async () => {

        if (
            timer
        ) {

            clearInterval(
                timer
            );

            timer =
                null;
        }


        stopTeacherCountdown();


        await S.auth.signOut();


        location.reload();
    };


/* =========================================
   OPEN APP
========================================= */

async function openApp() {

    $('#loginView').hidden =
        true;

    $('#appView').hidden =
        false;


    await loadExam();

    await loadControl();

    await loadResults();


    if (
        timer
    ) {

        clearInterval(
            timer
        );
    }


    timer =
        setInterval(
            async () => {

                await loadControl();


                if (
                    !$('#results').hidden
                ) {

                    await loadResults();
                }

            },
            2500
        );
}


/* =========================================
   LOAD EXAM
========================================= */

async function loadExam() {

    try {

        const exam =
            await rpc(
                'teacher_exam_get'
            );


        if (
            exam
        ) {

            $('#title').value =
                exam.title;


            $('#duration').value =
                exam.durationMinutes;


            questions =
                Array.isArray(
                    exam.questions
                )
                    ? exam.questions
                    : [];

        } else {

            questions = [
                {
                    text:
                        'คำถามข้อ 1',

                    choices: [
                        'ตัวเลือก ก',
                        'ตัวเลือก ข',
                        'ตัวเลือก ค',
                        'ตัวเลือก ง'
                    ],

                    correct:
                        0
                }
            ];
        }


        renderEditor();


    } catch (
        error
    ) {

        msg(
            error.message
        );
    }
}


/* =========================================
   QUESTION EDITOR
========================================= */

function renderEditor() {

    const container =
        $('#questionEditor');


    container.innerHTML =
        '';


    questions.forEach(
        (
            question,
            questionIndex
        ) => {


            const article =
                document
                    .createElement(
                        'article'
                    );


            article.className =
                'qedit';


            article.innerHTML = `

                <div class="qhead">

                    <b>
                        ข้อ ${questionIndex + 1}
                    </b>


                    <button
                        type="button"
                        class="delete"
                    >
                        ลบ
                    </button>

                </div>


                <label>

                    คำถาม

                    <input
                        data-text
                        value="${esc(
                            question.text
                        )}"
                    >

                </label>


                ${
                    question
                        .choices
                        .map(
                            (
                                choice,
                                index
                            ) => `

                                <div class="choice-edit">

                                    <input
                                        type="radio"
                                        name="r${questionIndex}"
                                        value="${index}"
                                        ${
                                            question.correct ===
                                            index

                                                ? 'checked'
                                                : ''
                                        }
                                    >


                                    <b>
                                        ${
                                            labels[index]
                                            ||
                                            index + 1
                                        }
                                    </b>


                                    <input
                                        data-c="${index}"
                                        value="${esc(
                                            choice
                                        )}"
                                    >


                                    <button
                                        type="button"
                                        data-rm="${index}"
                                    >
                                        ×
                                    </button>

                                </div>

                            `
                        )
                        .join('')
                }


                <button
                    type="button"
                    class="add-choice"
                >
                    + เพิ่มตัวเลือก
                </button>

            `;


            article
                .querySelector(
                    '.delete'
                )
                .onclick =
                () => {

                    questions.splice(
                        questionIndex,
                        1
                    );

                    renderEditor();
                };


            article
                .querySelector(
                    '[data-text]'
                )
                .oninput =
                e => {

                    question.text =
                        e.target.value;
                };


            article
                .querySelectorAll(
                    '[data-c]'
                )
                .forEach(
                    input => {

                        input.oninput =
                            e => {

                                question.choices[
                                    Number(
                                        e.target.dataset.c
                                    )
                                ] =
                                    e.target.value;
                            };
                    }
                );


            article
                .querySelectorAll(
                    'input[type="radio"]'
                )
                .forEach(
                    radio => {

                        radio.onchange =
                            e => {

                                question.correct =
                                    Number(
                                        e.target.value
                                    );
                            };
                    }
                );


            article
                .querySelectorAll(
                    '[data-rm]'
                )
                .forEach(
                    button => {

                        button.onclick =
                            () => {

                                if (
                                    question.choices
                                        .length <= 2
                                ) {

                                    alert(
                                        'ต้องมีอย่างน้อย 2 ตัวเลือก'
                                    );

                                    return;
                                }


                                question
                                    .choices
                                    .splice(
                                        Number(
                                            button.dataset.rm
                                        ),
                                        1
                                    );


                                question.correct =
                                    0;


                                renderEditor();
                            };
                    }
                );


            article
                .querySelector(
                    '.add-choice'
                )
                .onclick =
                () => {

                    if (
                        question
                            .choices
                            .length >= 6
                    ) {

                        alert(
                            'เพิ่มได้สูงสุด 6 ตัวเลือก'
                        );

                        return;
                    }


                    question
                        .choices
                        .push(
                            'ตัวเลือกใหม่'
                        );


                    renderEditor();
                };


            container
                .appendChild(
                    article
                );
        }
    );
}


/* =========================================
   ADD QUESTION
========================================= */

$('#addQuestion').onclick =
    () => {

        questions.push({
            text:
                `คำถามข้อ ${
                    questions.length + 1
                }`,

            choices: [
                'ตัวเลือก ก',
                'ตัวเลือก ข',
                'ตัวเลือก ค',
                'ตัวเลือก ง'
            ],

            correct:
                0
        });


        renderEditor();
    };


/* =========================================
   SAVE EXAM
========================================= */

$('#saveExam').onclick =
    async () => {

        try {

            await rpc(
                'teacher_exam_save',
                {
                    payload: {

                        title:
                            $('#title')
                                .value
                                .trim(),

                        durationMinutes:
                            Number(
                                $('#duration')
                                    .value
                            ),

                        questions
                    }
                }
            );


            msg(
                'บันทึกชุดข้อสอบแล้ว'
            );


            await loadExam();

            await loadControl();


        } catch (
            error
        ) {

            msg(
                error.message
            );
        }
    };


/* =========================================
   CONTROL
========================================= */

async function loadControl() {

    try {

        const data =
            await rpc(
                'teacher_control_state'
            );


        if (
            !data
        ) {

            stopTeacherCountdown();


            $('#controlBox').innerHTML = `

                <div class="waiting">

                    <h2>
                        ยังไม่มีชุดข้อสอบ
                    </h2>

                    <p>
                        ไปที่แท็บสร้างข้อสอบก่อน
                    </p>

                </div>

            `;


            return;
        }


        const status =
            data.sessionStatus ||
            'none';


        const currentPosition =
            Number(
                data.currentPosition ??
                -1
            );


        const next =
            currentPosition + 2;


        stopTeacherCountdown();


        $('#controlBox').innerHTML = `

            <div class="control-head">

                <div>

                    <h2>
                        ${esc(
                            data.title
                        )}
                    </h2>


                    <p class="muted">

                        ${data.total} ข้อ

                        •

                        ${
                            status ===
                            'none'

                                ? 'ยังไม่มีรอบ'

                                : status ===
                                  'waiting'

                                    ? 'รอเริ่ม'

                                    : status ===
                                      'live'

                                        ? 'กำลังติว'

                                        : 'จบแล้ว'
                        }

                    </p>

                </div>


                <div class="actions">

                    ${
                        status === 'none' ||
                        status === 'finished'

                            ? `

                                <button
                                    id="startRound"
                                    class="primary"
                                    type="button"
                                >
                                    เริ่มรอบใหม่
                                </button>

                            `

                            : ''
                    }


                    ${
                        status ===
                        'waiting'

                            ? `

                                <button
                                    id="releaseNext"
                                    class="primary"
                                    type="button"
                                >
                                    ส่งข้อ 1
                                </button>

                            `

                            : ''
                    }


                    ${
                        status ===
                            'live'
                        &&
                        next <=
                            data.total

                            ? `

                                <button
                                    id="releaseNext"
                                    class="primary"
                                    type="button"
                                >
                                    ส่งข้อ ${next}
                                </button>

                            `

                            : ''
                    }


                    ${
                        status ===
                        'live'

                            ? `

                                <button
                                    id="finishRound"
                                    type="button"
                                >
                                    จบการติว
                                </button>

                            `

                            : ''
                    }

                </div>

            </div>


            ${
                status ===
                'live'

                    ? `

                        <div
                            id="teacherQuestionTimer"
                            class="question-timer teacher-question-timer"
                        >

                            <div class="timer-left">

                                <span>
                                    ⏱ เวลาที่เหลือ
                                </span>


                                <strong
                                    id="teacherTimerText"
                                >
                                    ${formatTeacherTime(
                                        data.remainingSeconds
                                    )}
                                </strong>

                            </div>


                            <div class="timer-end">

                                <span>
                                    หมดเวลา
                                </span>


                                <b
                                    id="teacherEndTime"
                                >
                                    --
                                </b>

                            </div>

                        </div>


                        <div class="stats">

                            <div class="stat">

                                <span>
                                    ข้อปัจจุบัน
                                </span>

                                <b>
                                    ${
                                        currentPosition + 1
                                    }
                                </b>

                            </div>


                            <div class="stat">

                                <span>
                                    ตอบแล้ว
                                </span>

                                <b>
                                    ${
                                        data.answeredCount
                                    }/${
                                        data.studentCount
                                    }
                                </b>

                            </div>


                            <div class="stat">

                                <span>
                                    ถูก
                                </span>

                                <b>
                                    ${
                                        data.correctCount
                                    }
                                </b>

                            </div>


                            <div class="stat">

                                <span>
                                    ผิด
                                </span>

                                <b>
                                    ${
                                        data.wrongCount
                                    }
                                </b>

                            </div>

                        </div>

                    `

                    : ''
            }

        `;


        /* TIMER */

        if (
            status === 'live'
        ) {

            if (
                data.timeExpired === true
                ||
                Number(
                    data.remainingSeconds
                ) <= 0
            ) {

                const timerBox =
                    $('#teacherQuestionTimer');

                const timerText =
                    $('#teacherTimerText');


                if (
                    timerText
                ) {

                    timerText.textContent =
                        '00:00';
                }


                if (
                    timerBox
                ) {

                    timerBox
                        .classList
                        .add(
                            'danger'
                        );
                }

            } else {

                startTeacherCountdown(
                    data.remainingSeconds
                );
            }
        }


        /* START ROUND */

        $('#startRound')
            ?.addEventListener(
                'click',
                async () => {

                    if (
                        !confirm(
                            'เริ่มรอบใหม่โดยใช้ชุดข้อสอบนี้?'
                        )
                    ) {

                        return;
                    }


                    try {

                        await rpc(
                            'teacher_round_start'
                        );


                        await loadControl();

                        await loadResults();


                    } catch (
                        error
                    ) {

                        msg(
                            error.message
                        );
                    }
                }
            );


        /* RELEASE NEXT */

        $('#releaseNext')
            ?.addEventListener(
                'click',
                async () => {

                    try {

                        await rpc(
                            'teacher_release_next'
                        );


                        await loadControl();

                        await loadResults();


                    } catch (
                        error
                    ) {

                        msg(
                            error.message
                        );
                    }
                }
            );


        /* FINISH */

        $('#finishRound')
            ?.addEventListener(
                'click',
                async () => {

                    if (
                        !confirm(
                            'จบการติวตอนนี้?'
                        )
                    ) {

                        return;
                    }


                    try {

                        await rpc(
                            'teacher_round_finish'
                        );


                        await loadControl();

                        await loadResults();


                    } catch (
                        error
                    ) {

                        msg(
                            error.message
                        );
                    }
                }
            );


    } catch (
        error
    ) {

        msg(
            error.message
        );
    }
}


/* =========================================
   RESULT ANSWER TAG
========================================= */

function renderAnswerTag(
    answer
) {

    if (
        answer.status ===
            'timeout'
        ||
        answer.choice ===
            null
        ||
        answer.choice ===
            undefined
    ) {

        return `

            <span
                class="tag timeout"
                title="หมดเวลา ข้อนี้ได้ 0 คะแนน"
            >
                ${answer.question}: ⏰ 0
            </span>

        `;
    }


    if (
        answer.status ===
        'pending'
    ) {

        return `

            <span
                class="tag pending"
                title="ยังไม่ได้ตอบ"
            >
                ${answer.question}: รอตอบ
            </span>

        `;
    }


    if (
        answer.status ===
        'not_released'
    ) {

        return `

            <span
                class="tag not-released"
                title="ครูยังไม่ได้ส่งข้อนี้"
            >
                ${answer.question}: -
            </span>

        `;
    }


    const choice =
        Number(
            answer.choice
        );


    const choiceLabel =
        labels[
            choice
        ] || '-';


    return `

        <span
            class="tag ${
                answer.correct
                    ? 'ok'
                    : 'no'
            }"
        >
            ${answer.question}:${choiceLabel}
            ${
                answer.correct
                    ? '✓'
                    : '✕'
            }
        </span>

    `;
}


/* =========================================
   RESULTS
========================================= */

async function loadResults() {

    try {

        const result =
            await rpc(
                'teacher_results'
            );


        const rows =
            Array.isArray(
                result
            )

                ? result
                : [];


        const done =
            rows.filter(
                student =>
                    student.finished
            ).length;


        $('#summary').textContent =
            `นักเรียน ${rows.length} คน • จบแล้ว ${done} คน`;


        if (
            rows.length === 0
        ) {

            $('#resultRows').innerHTML = `

                <tr>

                    <td colspan="6">
                        ยังไม่มีนักเรียน
                    </td>

                </tr>

            `;


            return;
        }


        $('#resultRows').innerHTML =
            rows.map(
                student => {


                    const answers =
                        Array.isArray(
                            student.answers
                        )

                            ? student.answers
                            : [];


                    const answersHtml =
                        answers
                            .map(
                                renderAnswerTag
                            )
                            .join('');


                    return `

                        <tr>

                            <td>
                                ${esc(
                                    student.studentId
                                )}
                            </td>


                            <td>
                                ${esc(
                                    student.studentName
                                )}
                            </td>


                            <td>

                                <b>
                                    ${
                                        Number(
                                            student.score
                                        ) || 0
                                    }/${
                                        Number(
                                            student.total
                                        ) || 0
                                    }
                                </b>

                            </td>


                            <td>

                                <span
                                    class="status ${
                                        student.finished
                                            ? 'done'
                                            : 'doing'
                                    }"
                                >
                                    ${
                                        student.finished
                                            ? 'จบแล้ว'
                                            : 'กำลังทำ'
                                    }
                                </span>

                            </td>


                            <td>

                                ${
                                    answersHtml ||
                                    '<span class="muted">-</span>'
                                }

                            </td>


                            <td>

                                <button
                                    type="button"
                                    class="reset-one danger-btn"
                                    data-id="${
                                        student.attemptId
                                    }"
                                >
                                    รีเซ็ต
                                </button>

                            </td>

                        </tr>

                    `;
                }
            )
            .join('');


        document
            .querySelectorAll(
                '.reset-one'
            )
            .forEach(
                button => {

                    button.onclick =
                        async () => {

                            if (
                                !confirm(
                                    'รีเซ็ตคะแนนนักเรียนคนนี้?'
                                )
                            ) {

                                return;
                            }


                            try {

                                await rpc(
                                    'teacher_reset_attempt',
                                    {
                                        p_attempt_id:
                                            button.dataset.id
                                    }
                                );


                                await loadResults();

                                await loadControl();


                            } catch (
                                error
                            ) {

                                msg(
                                    error.message
                                );
                            }
                        };
                }
            );


    } catch (
        error
    ) {

        msg(
            error.message
        );
    }
}


/* =========================================
   REFRESH RESULTS
========================================= */

$('#refreshResults').onclick =
    loadResults;


/* =========================================
   CLEAR ALL
========================================= */

$('#clearAll').onclick =
    async () => {

        if (
            !confirm(
                'เคลียร์คะแนนและคำตอบนักเรียนทั้งหมดในรอบนี้? การดำเนินการนี้ย้อนกลับไม่ได้'
            )
        ) {

            return;
        }


        try {

            await rpc(
                'teacher_clear_results'
            );


            await loadResults();

            await loadControl();


        } catch (
            error
        ) {

            msg(
                error.message
            );
        }
    };


/* =========================================
   TABS
========================================= */

document
    .querySelectorAll(
        '.tab'
    )
    .forEach(
        button => {

            button.onclick =
                () => {


                    document
                        .querySelectorAll(
                            '.tab'
                        )
                        .forEach(
                            tab => {

                                tab
                                    .classList
                                    .toggle(
                                        'active',
                                        tab ===
                                        button
                                    );
                            }
                        );


                    [
                        'control',
                        'builder',
                        'results'
                    ]
                        .forEach(
                            id => {

                                $('#' + id)
                                    .hidden =

                                    id !==
                                    button.dataset.tab;
                            }
                        );


                    if (
                        button
                            .dataset
                            .tab ===
                        'results'
                    ) {

                        loadResults();
                    }
                };
        }
    );


/* =========================================
   MESSAGE
========================================= */

function msg(
    text
) {

    $('#teacherMsg')
        .textContent =
        text || '';


    setTimeout(
        () => {

            $('#teacherMsg')
                .textContent =
                '';

        },
        3500
    );
}


/* =========================================
   RESTORE SESSION
========================================= */

S.auth
    .getSession()
    .then(
        ({
            data
        }) => {

            if (
                data.session
            ) {

                openApp();
            }
        }
    );
/* =========================================
   EDUCATION HUB: NAVIGATION + CLASS MODULES
========================================= */
const hubTitles = {
  overview: 'ภาพรวม', attendance: 'เช็คชื่อ', grades: 'คะแนน & เกรด',
  schedule: 'ตารางเรียน', tutor: 'ติวข้อสอบ', students: 'นักเรียน', settings: 'ตั้งค่า'
};
let attendanceCache = null;
let gradebookCache = [];
let scheduleCache = [];

function localDateValue(date = new Date()) {
  const offset = date.getTimezoneOffset();
  return new Date(date.getTime() - offset * 60000).toISOString().slice(0, 10);
}

function setHubView(view) {
  if (!hubTitles[view]) return;
  document.querySelectorAll('.hub-view').forEach(section => { section.hidden = section.id !== `hub-${view}`; });
  document.querySelectorAll('.hub-nav').forEach(button => button.classList.toggle('active', button.dataset.view === view));
  const title = document.querySelector('#hubPageTitle');
  if (title) title.textContent = hubTitles[view];
  const mobileMenu = document.querySelector('#mobileMenu');
  if (mobileMenu) mobileMenu.hidden = true;
  document.querySelector('#mobileMore')?.setAttribute('aria-expanded', 'false');
  window.scrollTo({ top: 0, behavior: 'smooth' });
  if (view === 'attendance') loadAttendance();
  if (view === 'grades') loadGradebook();
  if (view === 'schedule') loadSchedule();
  if (view === 'students') loadStudents();
}

document.querySelectorAll('.hub-nav').forEach(button => button.addEventListener('click', () => setHubView(button.dataset.view)));
document.querySelectorAll('[data-go]').forEach(button => button.addEventListener('click', () => setHubView(button.dataset.go)));

function toggleMobileMenu() {
  const menu = document.querySelector('#mobileMenu');
  if (!menu) return;
  menu.hidden = !menu.hidden;
  document.querySelector('#mobileMore')?.setAttribute('aria-expanded', String(!menu.hidden));
}
document.querySelector('#mobileMore')?.addEventListener('click', toggleMobileMenu);
document.querySelector('#bottomMore')?.addEventListener('click', toggleMobileMenu);
document.querySelector('#mobileLogout')?.addEventListener('click', () => document.querySelector('#logout')?.click());

document.querySelector('#copyAttendanceLink')?.addEventListener('click', async () => {
  const url = new URL('attendance.html', location.href).href;
  try { await navigator.clipboard.writeText(url); msg('คัดลอกลิงก์เช็คชื่อแล้ว'); }
  catch { prompt('คัดลอกลิงก์นี้', url); }
});

function setDefaultDates() {
  const today = localDateValue();
  if ($('#attendanceDate')) $('#attendanceDate').value = today;
  if ($('#gradeDate')) $('#gradeDate').value = today;
  if ($('#attendanceLink')) $('#attendanceLink').textContent = new URL('attendance.html', location.href).href;
}
setDefaultDates();

async function loadTeacherProfile() {
  const { data } = await S.auth.getUser();
  const email = data?.user?.email || '-';
  if ($('#teacherAccount')) $('#teacherAccount').textContent = email;
}

async function loadAttendance() {
  try {
    attendanceCache = await rpc('teacher_attendance_dashboard');
    renderAttendance(attendanceCache || { active: null, sessions: [] });
  } catch (error) { msg(error.message); }
}

function renderAttendance(data) {
  const activeBox = $('#activeAttendance');
  const active = data.active;
  if (active) {
    const records = Array.isArray(active.records) ? active.records : [];
    activeBox.className = 'card module-card active-session';
    activeBox.innerHTML = `<div class="active-code-label">รหัสเช็คชื่อ</div><div class="attendance-code">${esc(active.code)}</div><h3>${esc(active.title)}</h3><p class="muted">มาเรียน ${records.filter(r => r.status === 'present').length} • มาสาย ${records.filter(r => r.status === 'late').length}</p><div class="attendance-records">${records.length ? records.map(r => `<div><span><b>${esc(r.studentCode)}</b> ${esc(r.studentName)}</span><em class="${r.status === 'late' ? 'late' : 'present'}">${r.status === 'late' ? 'มาสาย' : 'มาเรียน'}</em></div>`).join('') : '<p class="muted">ยังไม่มีนักเรียนเช็คชื่อ</p>'}</div><button id="closeAttendance" class="danger-btn wide" type="button">ปิดรอบเช็คชื่อ</button>`;
    $('#closeAttendance').onclick = async () => {
      if (!confirm('ปิดรอบเช็คชื่อนี้?')) return;
      try { await rpc('teacher_attendance_close', { p_session_id: active.id }); await loadAttendance(); }
      catch (error) { msg(error.message); }
    };
  } else {
    activeBox.className = 'card module-card empty-state';
    activeBox.innerHTML = '<span>○</span><h3>ยังไม่มีรอบที่เปิดอยู่</h3><p>สร้างรอบใหม่เพื่อรับรหัสเช็คชื่อ</p>';
  }
  const sessions = Array.isArray(data.sessions) ? data.sessions : [];
  $('#attendanceHistory').innerHTML = sessions.length ? sessions.map(s => `<div class="record-row"><div><b>${esc(s.title)}</b><small>${esc(s.sessionDate)} • รหัส ${esc(s.code)}</small></div><span>${Number(s.attendeeCount || 0)} คน</span><em class="${s.status === 'open' ? 'present' : 'closed'}">${s.status === 'open' ? 'เปิดอยู่' : 'ปิดแล้ว'}</em></div>`).join('') : '<p class="muted">ยังไม่มีประวัติ</p>';
}

$('#attendanceCreateForm')?.addEventListener('submit', async event => {
  event.preventDefault();
  try {
    await rpc('teacher_attendance_create', {
      p_title: $('#attendanceTitle').value.trim(), p_session_date: $('#attendanceDate').value,
      p_grace_minutes: Number($('#attendanceGrace').value)
    });
    $('#attendanceTitle').value = '';
    msg('สร้างรอบเช็คชื่อแล้ว');
    await loadAttendance();
  } catch (error) { msg(error.message); }
});
$('#refreshAttendance')?.addEventListener('click', loadAttendance);

async function loadGradebook() {
  try { gradebookCache = await rpc('teacher_gradebook_get') || []; renderGradebook(gradebookCache); }
  catch (error) { msg(error.message); }
}

function renderGradebook(items) {
  const list = $('#gradebookList');
  if (!items.length) { list.innerHTML = '<div class="card empty-state">ยังไม่มีรายการคะแนน</div>'; return; }
  list.innerHTML = items.map(item => {
    const grades = Array.isArray(item.grades) ? item.grades : [];
    return `<article class="card grade-item"><div class="section-head"><div><span class="grade-category">${esc(item.category)}</span><h3>${esc(item.title)}</h3><p class="muted">เต็ม ${item.maxScore} • น้ำหนัก ${item.weight}% • ${esc(item.term || 'ไม่ระบุภาคเรียน')}</p></div><button class="danger-btn delete-grade-item" data-id="${item.id}" type="button">ลบ</button></div><form class="grade-entry" data-id="${item.id}"><input name="studentCode" required placeholder="รหัสนักเรียน"><input name="studentName" required placeholder="ชื่อ - นามสกุล"><input name="score" type="number" min="0" max="${item.maxScore}" step="0.01" required placeholder="คะแนน"><input name="note" placeholder="หมายเหตุ"><button class="primary" type="submit">บันทึก</button></form><div class="grade-rows">${grades.length ? grades.map(g => `<div><span><b>${esc(g.studentCode)}</b> ${esc(g.studentName)}</span><strong>${g.score}/${item.maxScore}</strong><em>${g.letter}</em></div>`).join('') : '<p class="muted">ยังไม่มีคะแนนนักเรียน</p>'}</div></article>`;
  }).join('');
  document.querySelectorAll('.grade-entry').forEach(form => form.addEventListener('submit', saveGrade));
  document.querySelectorAll('.delete-grade-item').forEach(button => button.addEventListener('click', deleteGradeItem));
}

$('#gradeItemForm')?.addEventListener('submit', async event => {
  event.preventDefault();
  try {
    await rpc('teacher_grade_item_create', { p_title: $('#gradeTitle').value.trim(), p_category: $('#gradeCategory').value.trim(), p_max_score: Number($('#gradeMax').value), p_weight: Number($('#gradeWeight').value), p_term: $('#gradeTerm').value.trim(), p_item_date: $('#gradeDate').value });
    $('#gradeTitle').value = '';
    msg('สร้างรายการคะแนนแล้ว');
    await loadGradebook();
  } catch (error) { msg(error.message); }
});

async function saveGrade(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const values = new FormData(form);
  try {
    await rpc('teacher_grade_save', { p_item_id: form.dataset.id, p_student_code: values.get('studentCode').trim(), p_student_name: values.get('studentName').trim(), p_score: Number(values.get('score')), p_note: values.get('note').trim() });
    form.reset(); msg('บันทึกคะแนนแล้ว'); await loadGradebook();
  } catch (error) { msg(error.message); }
}

async function deleteGradeItem(event) {
  if (!confirm('ลบรายการคะแนนนี้และคะแนนทั้งหมดในรายการ?')) return;
  try { await rpc('teacher_grade_item_delete', { p_item_id: event.currentTarget.dataset.id }); await loadGradebook(); }
  catch (error) { msg(error.message); }
}

const dayNames = ['', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
async function loadSchedule() {
  try { scheduleCache = await rpc('teacher_schedule_get') || []; renderSchedule(scheduleCache); }
  catch (error) { msg(error.message); }
}

function renderSchedule(items) {
  const board = $('#scheduleBoard');
  board.innerHTML = Array.from({ length: 7 }, (_, index) => {
    const day = index + 1;
    const rows = items.filter(item => Number(item.dayOfWeek) === day);
    return `<section class="schedule-day"><h3>${dayNames[day]}</h3>${rows.length ? rows.map(item => `<article><time>${String(item.startTime).slice(0, 5)}–${String(item.endTime).slice(0, 5)}</time><div><b>${esc(item.title)}</b><small>${item.room ? `ห้อง ${esc(item.room)}` : 'ออนไลน์'}${item.note ? ` • ${esc(item.note)}` : ''}</small>${item.onlineUrl ? `<a href="${esc(item.onlineUrl)}" target="_blank" rel="noopener">เข้าห้องออนไลน์ ↗</a>` : ''}</div><button class="schedule-delete" data-id="${item.id}" type="button" aria-label="ลบ">×</button></article>`).join('') : '<p>ไม่มีคาบเรียน</p>'}</section>`;
  }).join('');
  document.querySelectorAll('.schedule-delete').forEach(button => button.addEventListener('click', async () => {
    if (!confirm('ลบคาบเรียนนี้?')) return;
    try { await rpc('teacher_schedule_delete', { p_schedule_id: button.dataset.id }); await loadSchedule(); }
    catch (error) { msg(error.message); }
  }));
}

$('#scheduleForm')?.addEventListener('submit', async event => {
  event.preventDefault();
  try {
    await rpc('teacher_schedule_create', { p_title: $('#scheduleTitle').value.trim(), p_day_of_week: Number($('#scheduleDay').value), p_start_time: $('#scheduleStart').value, p_end_time: $('#scheduleEnd').value, p_room: $('#scheduleRoom').value.trim(), p_online_url: $('#scheduleUrl').value.trim(), p_note: $('#scheduleNote').value.trim() });
    event.currentTarget.reset(); msg('เพิ่มคาบเรียนแล้ว'); await loadSchedule();
  } catch (error) { msg(error.message); }
});

async function loadStudents() {
  try {
    const [attendance, grades] = await Promise.all([rpc('teacher_attendance_dashboard'), rpc('teacher_gradebook_get')]);
    const map = new Map();
    const add = (code, name, source) => { if (!code) return; const current = map.get(code) || { code, name, sources: new Set() }; current.name = name || current.name; current.sources.add(source); map.set(code, current); };
    (attendance?.active?.records || []).forEach(r => add(r.studentCode, r.studentName, 'เช็คชื่อ'));
    (grades || []).forEach(item => (item.grades || []).forEach(g => add(g.studentCode, g.studentName, 'คะแนน')));
    const students = [...map.values()].sort((a, b) => a.code.localeCompare(b.code));
    $('#studentDirectory').innerHTML = students.length ? `<div class="student-row student-head"><b>รหัส</b><b>ชื่อ - นามสกุล</b><b>พบในระบบ</b></div>${students.map(s => `<div class="student-row"><span>${esc(s.code)}</span><b>${esc(s.name)}</b><small>${[...s.sources].join(', ')}</small></div>`).join('')}` : '<div class="empty-state">ยังไม่มีข้อมูลนักเรียนจากการเช็คชื่อหรือสมุดคะแนน</div>';
  } catch (error) { msg(error.message); }
}
$('#refreshStudents')?.addEventListener('click', loadStudents);

const originalOpenApp = openApp;
openApp = async function () {
  await originalOpenApp();
  document.querySelector('.teacher-public-header')?.setAttribute('hidden', '');
  document.querySelector('.teacher-main')?.classList.add('app-open');
  setHubView('overview');
  loadTeacherProfile();
};
