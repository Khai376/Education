import { createRouter, createWebHistory } from "vue-router";

import TeacherLayout from "../layouts/TeacherLayout.vue";
import { supabase } from "../services/supabase";

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
  history: createWebHistory(import.meta.env.BASE_URL),

  routes: [
    // =========================
    // Default / Login
    // =========================
    {
      path: "/",
      redirect: "/teacher",
    },
    {
      path: "/login",
      name: "login",
      component: () => import("../shared/Login.vue"),
      meta: {
        guestOnly: true,
      },
    },

    // =========================
    // Teacher - protected
    // =========================
    {
      path: "/teacher",
      component: TeacherLayout,
      meta: {
        requiresTeacherAuth: true,
      },
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
    // Student
    // =========================
    {
      path: "/student",
      name: "student-home",
      component: StudentHome,
    },
    {
      path: "/student/attendance",
      name: "student-attendance",
      component: StudentAttendance,
    },
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

// =========================================
// Authentication Guard
// =========================================
router.beforeEach(async (to) => {
  try {
    const {
      data: { session },
      error,
    } = await supabase.auth.getSession();

    if (error) {
      console.error("Auth session error:", error);
    }

    // Teacher routes must have a Supabase session.
    if (to.matched.some((record) => record.meta.requiresTeacherAuth)) {
      if (!session) {
        return {
          path: "/login",
          query: {
            redirect: to.fullPath,
          },
          replace: true,
        };
      }
    }

    // Logged-in teacher should not stay on the login page.
    if (to.meta.guestOnly && session) {
      const redirect =
        typeof to.query.redirect === "string" &&
        to.query.redirect.startsWith("/")
          ? to.query.redirect
          : "/teacher";

      return {
        path: redirect,
        replace: true,
      };
    }

    return true;
  } catch (error) {
    console.error("Router auth guard error:", error);

    if (to.matched.some((record) => record.meta.requiresTeacherAuth)) {
      return {
        path: "/login",
        query: {
          redirect: to.fullPath,
        },
        replace: true,
      };
    }

    return true;
  }
});

export default router;
