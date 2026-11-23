<div align="center">

# 💈 Rayeq · رايق

**Arabic-first grooming operations platform — booking, dispatch and payroll for a company-managed pilot in Minya**

[![Live Demo](https://img.shields.io/badge/🚀_Live_Platform-Visit-success?style=for-the-badge)](https://rayeq-platform.onrender.com)

[![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat-square&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=flat-square&logo=javascript&logoColor=black)](https://developer.mozilla.org/docs/Web/JavaScript)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Flutter](https://img.shields.io/badge/Flutter_App-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Render](https://img.shields.io/badge/Render-46E3B7?style=flat-square&logo=render&logoColor=black)](https://render.com)

</div>

---

## 🌐 Live

- **Platform:** [rayeq-platform.onrender.com](https://rayeq-platform.onrender.com)
- **Dashboard:** [rayeq-platform.onrender.com/dashboard](https://rayeq-platform.onrender.com/dashboard)

## ✨ Features

- 📋 **Operations dashboard + JSON API** (`/api/v1`) for a company-managed grooming service.
- 👷 **Worker onboarding with approval gate** — registration creates a pending applicant; admin links verified applicants to active employees with skills and areas.
- 🔐 **Security by default** — scrypt password hashing with per-user salt, HttpOnly SameSite=Strict cookie sessions, Bearer tokens for the native app, sessions hashed in Postgres with 7-day expiry.
- 🗓️ **Overlap-safe dispatch** — serializes bookings per employee across full time intervals plus a travel buffer.
- 💰 **Money handled as integer EGP piastres**, with payroll kept separate from booking revenue — marking a job complete never marks it paid.
- 🧩 **Idempotent API** — idempotency keys scoped per user and exact validated payload; JSON `{data}` / `{error}` contract documented in `docs/API-CONTRACT.md`.
- ✉️ **Vendor-neutral SMTP** — switchable to Mailjet through environment variables alone; registration fails closed without it.
- 📱 **Companion Flutter app** using the same login and API.

## 🛠️ Tech Stack

| Layer | Choice |
| --- | --- |
| Backend | Node.js 22+ |
| Database | PostgreSQL (dedicated `rayeq_` tables) |
| Mobile | Flutter |
| Hosting | Render |

## 🚀 Getting Started

```bash
npm ci
# configure .env.local from .env.example
npm run dev      # development
npm run build && npm start   # production
```

The startup migration touches only `rayeq_` tables in the configured dedicated database.

---

<div align="center">

## 👨‍💻 Developed by [Angelo Rezq](https://github.com/angelo-rezq)

**Full-Stack Developer · Flutter · Next.js · React**

[![Portfolio](https://img.shields.io/badge/Portfolio-black?style=for-the-badge)](https://angelo-portfolio.angluosr.workers.dev)
[![WhatsApp](https://img.shields.io/badge/WhatsApp-Chat-25D366?style=for-the-badge&logo=whatsapp&logoColor=white)](https://wa.me/201127570256)
[![Email](https://img.shields.io/badge/Email-angelo.rezq.dev%40gmail.com-EA4335?style=for-the-badge&logo=gmail&logoColor=white)](mailto:angelo.rezq.dev@gmail.com)

</div>
