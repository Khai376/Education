import { createRouter, createWebHistory } from "vue-router";

import TeacherLayout from "../layouts/TeacherLayout.vue";

// Teacher
import Dashboard from "../teacher/views/Dashboard.vue";
import Attendance from "../teacher/views/Attendance.vue";
import Students from "../teacher/views/Students.vue";
import Grades from "../teacher/views/Grades.vue";
import Schedule from "../teacher/views/Schedule.vue";
import Exams from "../teacher/views/Exams.vue";
import HomeroomTeachers from "../teacher/views/HomeroomTeachers.vue";
import SubjectsClasses from "../teacher/views/SubjectsClasses.vue";

// Student
import StudentHome from "../student/views/StudentHome.vue";
import StudentAttendance from "../student/views/StudentAttendance.vue";
import StudentExam from "../student/views/StudentHome.vue";

const router = createRouter({
  history: createWebHistory(),

  routes: [
    // =========================
    // Default
    // =========================

    {
      path: "/",
      redirect: "/teacher",
    },

    // =========================
    // Teacher
    // =========================

    {
      path: "/teacher",
      component: TeacherLayout,

      children: [
        {
          path: "",
          name: "teacher-home",
          component: Dashboard,
        },

        {
          path: "attendance",
          name: "teacher-attendance",
          component: Attendance,
        },
        {
          path: "homeroom-teachers",
          name: "teacher-homeroom-teachers",
          component: HomeroomTeachers,
        },
        {
          path: "subjects-classes",
          name: "teacher-subjects-classes",
          component: SubjectsClasses,
        },

        {
          path: "students",
          name: "teacher-students",
          component: Students,
        },

        {
          path: "grades",
          name: "teacher-grades",
          component: Grades,
        },

        {
          path: "schedule",
          name: "teacher-schedule",
          component: Schedule,
        },

        {
          path: "exams",
          name: "teacher-exams",
          component: Exams,
        },
      ],
    },

    // =========================
    // Student Home
    // =========================

    {
      path: "/student",
      name: "student-home",
      component: StudentHome,
    },

    // =========================
    // Student Attendance
    // =========================

    {
      path: "/student/attendance",
      name: "student-attendance",
      component: StudentAttendance,
    },

    // =========================
    // Student Exam
    // =========================

    {
      path: "/student/exam",
      name: "student-exam",
      component: StudentExam,
    },

    // =========================
    // Redirect old route
    // =========================

    {
      path: "/attendance",
      redirect: "/student/attendance",
    },
  ],
});

export default router;
