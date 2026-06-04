let schools = [
  { name: "EMEF Paulo Freire", students: 1240, teachers: 82, attendance: 94, approval: 88, status: "Regular" },
  { name: "EMEI Ana Neri", students: 680, teachers: 41, attendance: 91, approval: 92, status: "Regular" },
  { name: "EMEF Darcy Ribeiro", students: 980, teachers: 63, attendance: 87, approval: 81, status: "Atenção" },
  { name: "CMEI Esperança", students: 520, teachers: 34, attendance: 96, approval: 95, status: "Regular" },
];

const students = [
  { name: "Ana Beatriz Lima", school: "EMEF Paulo Freire", class: "7º A", attendance: "96%", grade: "8,7", status: "Ativo" },
  { name: "Carlos Henrique Souza", school: "EMEF Darcy Ribeiro", class: "9º B", attendance: "82%", grade: "6,1", status: "Recuperação" },
  { name: "Mariana Costa", school: "EMEI Ana Neri", class: "Infantil V", attendance: "94%", grade: "9,2", status: "Ativo" },
  { name: "João Pedro Martins", school: "CMEI Esperança", class: "3º C", attendance: "89%", grade: "7,4", status: "Acompanhar" },
];

const records = JSON.parse(localStorage.getItem("sigaeRecords") || "[]");
let apiAvailable = false;
let pendingLoginUser = null;

const supabaseConfig = {
  url: window.SIGAE_SUPABASE_URL || "",
  anonKey: window.SIGAE_SUPABASE_ANON_KEY || "",
  tables: {
    users: "usuarios",
    roles: "usuarios_cargos",
    enrollments: "matriculas",
    grades: "notas",
    attendance: "frequencias",
  },
};

const alerts = [
  ["Frequência crítica", "38 alunos abaixo de 75% exigem busca ativa."],
  ["Censo Escolar", "12 inconsistências aguardam conferência prévia."],
  ["Documentos", "24 históricos escolares pendentes de assinatura."],
  ["Comunicação", "86% de leitura no comunicado municipal desta semana."],
];

const activities = [
  ["Gestor municipal", "Exportou relatório consolidado de matrículas."],
  ["Secretaria escolar", "Efetivou rematrículas do 6º ano."],
  ["Professor", "Lançou notas de Matemática para 8º A."],
  ["Auditoria", "Backup diário concluído com sucesso."],
];

const views = {
  dashboard: {
    title: "Painel executivo da rede municipal",
    subtitle: "Indicadores consolidados para acompanhar escolas, matrículas, frequência, rendimento e comunicação em tempo real.",
    render: renderDashboard,
  },
  administrativo: {
    title: "Módulo Administrativo",
    subtitle: "Cadastros, matrículas, transferências, turmas, calendário letivo, documentos, ocorrências e gestão documental.",
    render: () => renderModule("Administrativo", [
      ["Escolas", "Gerencie unidades, etapas, turnos, contatos, infraestrutura e situação operacional.", ["Cadastro de escolas", "Controle de turmas", "Calendário letivo"]],
      ["Pessoas", "Cadastre alunos, professores, coordenadores, gestores e responsáveis com vínculo escolar.", ["Matrículas e rematrículas", "Transferências", "Histórico escolar"]],
      ["Vida escolar", "Acompanhe frequência, evasão, ocorrências, documentos e diário de classe digital.", ["Declarações", "Gestão documental", "Controle de evasão"]],
    ]),
  },
  pedagogico: {
    title: "Módulo Pedagógico",
    subtitle: "Notas, frequência, planejamento, avaliações, recuperação paralela, indicadores de aprendizagem e relatórios pedagógicos.",
    render: renderPedagogico,
  },
  secretaria: {
    title: "Secretaria Escolar",
    subtitle: "Gestão completa da vida escolar do aluno, boletins, históricos, atas e relatórios exportáveis.",
    render: renderSecretaria,
  },
  portais: {
    title: "Portais de acesso",
    subtitle: "Experiências específicas para professor, aluno e responsáveis com dados, atividades e comunicação.",
    render: () => renderModule("Portais", [
      ["Portal do Professor", "Registro de frequência, notas, planejamento, materiais, atividades e desempenho das turmas.", ["Diário digital", "Envio de atividades", "Comunicação"]],
      ["Portal do Aluno", "Notas, frequência, boletim online, agenda, AVA, materiais e entrega de trabalhos.", ["Agenda escolar", "Boletim online", "Materiais de estudo"]],
      ["Portal dos Responsáveis", "Acompanhamento de notas, frequência, comunicados, mensagens e relatórios de desempenho.", ["Calendário", "Mensagens", "Rendimento"]],
    ]),
  },
  ava: {
    title: "Ambiente Virtual de Aprendizagem",
    subtitle: "Salas virtuais, biblioteca digital, videoaulas, fóruns, questionários e registro de participação.",
    render: renderAva,
  },
  censo: {
    title: "Integração com o Censo Escolar",
    subtitle: "Exportação, importação, validação de inconsistências e conferência prévia dos layouts oficiais.",
    render: renderCenso,
  },
  comunicacao: {
    title: "Comunicação",
    subtitle: "Central de notificações, mensagens internas, avisos por turma ou escola e registro de leitura.",
    render: renderComunicacao,
  },
  relatorios: {
    title: "Relatórios e Business Intelligence",
    subtitle: "Mais de 100 relatórios, exportação em PDF/Excel, painéis gráficos e filtros personalizados.",
    render: renderRelatorios,
  },
  seguranca: {
    title: "Segurança, LGPD e infraestrutura",
    subtitle: "Perfis de acesso, senhas criptografadas, auditoria, backup diário, criptografia e monitoramento contínuo.",
    render: renderSeguranca,
  },
};

const mainColumn = document.querySelector("#mainColumn");
const viewTitle = document.querySelector("#viewTitle");
const viewSubtitle = document.querySelector("#viewSubtitle");
const searchInput = document.querySelector("#globalSearch");
const sidebar = document.querySelector("#sidebar");
const loginScreen = document.querySelector("#loginScreen");
const appShell = document.querySelector("#appShell");
const loginForm = document.querySelector("#loginForm");
const loginFeedback = document.querySelector("#loginFeedback");
const formAlert = document.querySelector("#formAlert");
const rolePicker = document.querySelector("#rolePicker");
const roleOptions = document.querySelector("#roleOptions");
const profileSelect = document.querySelector("#profileSelect");

const roleToProfile = {
  Diretor: "Diretor",
  "Gestor municipal": "Gestor municipal",
  Gestor: "Gestor municipal",
  "Secretaria escolar": "Secretaria escolar",
  Professor: "Professor",
  Aluno: "Aluno",
  "Responsável": "Responsável",
  Administrador: "Administrador",
};

const profileToView = {
  Diretor: "administrativo",
  "Gestor municipal": "dashboard",
  "Secretaria escolar": "secretaria",
  Professor: "pedagogico",
  Aluno: "ava",
  "Responsável": "portais",
  Administrador: "seguranca",
};

const allProfiles = Object.keys(profileToView);

function badge(status) {
  const cls = status === "Regular" || status === "Ativo" ? "" : status === "Recuperação" || status === "Atenção" ? "warning" : "danger";
  return `<span class="badge ${cls}">${status}</span>`;
}

function renderKpis() {
  const totals = schools.reduce((acc, school) => {
    acc.students += Number(school.students);
    acc.teachers += Number(school.teachers);
    acc.attendance += Number(school.attendance);
    return acc;
  }, { students: 0, teachers: 0, attendance: 0 });
  const averageAttendance = Math.round(totals.attendance / Math.max(schools.length, 1));
  return `
    <section class="kpi-grid">
      <article class="kpi-card"><span>Alunos matriculados</span><strong>${totals.students.toLocaleString("pt-BR")}</strong><small class="trend">+6,4% no ano letivo</small></article>
      <article class="kpi-card"><span>Professores ativos</span><strong>${totals.teachers}</strong><small class="trend">98% com turmas vinculadas</small></article>
      <article class="kpi-card"><span>Frequência média</span><strong>${averageAttendance}%</strong><small class="trend">Meta municipal: 95%</small></article>
      <article class="kpi-card"><span>Documentos emitidos</span><strong>1.284</strong><small class="trend">Boletins, atas e históricos</small></article>
    </section>
  `;
}

function renderDashboard() {
  return `
    ${renderKpis()}
    <section class="panel chart-row">
      <div>
        <div class="panel-header">
          <div><p class="eyebrow">Rede municipal</p><h2>Alunos por escola</h2></div>
          <button class="secondary-action">Exportar Excel</button>
        </div>
        <div class="bar-chart">
          ${schools.map((school) => `
            <div class="bar-line">
              <strong>${school.name}</strong>
              <span class="bar-track"><span class="bar-fill" style="width:${Math.round(school.students / 13)}%"></span></span>
              <span>${school.students}</span>
            </div>
          `).join("")}
        </div>
      </div>
      <div>
        <div class="panel-header"><div><p class="eyebrow">Rendimento</p><h2>Indicadores finais</h2></div></div>
        <div class="donut" aria-label="78% de aprovação"></div>
        <div class="legend">
          <span><i style="background:var(--primary)"></i>Aprovação</span>
          <span><i style="background:var(--accent)"></i>Reprovação</span>
          <span><i style="background:var(--rose)"></i>Abandono</span>
        </div>
      </div>
    </section>
    ${renderSchoolTable()}
  `;
}

function renderSchoolTable() {
  return `
    <section class="panel">
      <div class="panel-header">
        <div><p class="eyebrow">Monitoramento</p><h2>Escolas acompanhadas</h2></div>
        <button class="secondary-action">Gerar relatório</button>
      </div>
      <table class="data-table">
        <thead><tr><th>Escola</th><th>Alunos</th><th>Professores</th><th>Frequência</th><th>Aprovação</th><th>Situação</th><th></th></tr></thead>
        <tbody>
          ${schools.map((school) => `
            <tr>
              <td><strong>${school.name}</strong></td>
              <td>${school.students}</td>
              <td>${school.teachers}</td>
              <td>${school.attendance}%</td>
              <td>${school.approval}%</td>
              <td>${badge(school.status)}</td>
              <td><button class="table-action">Abrir</button></td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    </section>
  `;
}

function renderModule(label, items) {
  return `
    ${renderKpis()}
    <section class="panel">
      <div class="panel-header">
        <div><p class="eyebrow">${label}</p><h2>Funcionalidades disponíveis</h2></div>
        <div class="filters"><button class="chip active">Todos</button><button class="chip">Ativos</button><button class="chip">Pendentes</button></div>
      </div>
      <div class="module-grid">
        ${items.map(([title, text, bullets]) => `
          <article class="module-card">
            <strong>${title}</strong>
            <p>${text}</p>
            <ul>${bullets.map((item) => `<li>${item}</li>`).join("")}</ul>
          </article>
        `).join("")}
      </div>
    </section>
    ${renderStudentTable()}
  `;
}

function renderStudentTable() {
  const saved = records.map((item) => ({
    name: item.name,
    school: item.school,
    class: item.type,
    attendance: "-",
    grade: "-",
    status: item.status,
  }));
  const rows = [...students, ...saved];
  return `
    <section class="panel">
      <div class="panel-header">
        <div><p class="eyebrow">Vida escolar</p><h2>Registros recentes</h2></div>
        <button class="secondary-action">Exportar PDF</button>
      </div>
      <table class="data-table">
        <thead><tr><th>Nome</th><th>Escola</th><th>Turma/Tipo</th><th>Frequência</th><th>Nota</th><th>Situação</th></tr></thead>
        <tbody>
          ${rows.map((student) => `
            <tr>
              <td><strong>${student.name}</strong></td>
              <td>${student.school}</td>
              <td>${student.class}</td>
              <td>${student.attendance}</td>
              <td>${student.grade}</td>
              <td>${badge(student.status)}</td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    </section>
  `;
}

function renderPedagogico() {
  return `
    <section class="panel">
      <div class="panel-header"><div><p class="eyebrow">Aprendizagem</p><h2>Desempenho por componente curricular</h2></div></div>
      <div class="progress-list">
        ${[
          ["Língua Portuguesa", 84],
          ["Matemática", 71],
          ["Ciências", 79],
          ["História e Geografia", 88],
          ["Arte e Educação Física", 93],
        ].map(([label, value]) => `
          <div class="progress-item">
            <div class="progress-top"><strong>${label}</strong><span>${value}%</span></div>
            <div class="progress"><span style="width:${value}%"></span></div>
          </div>
        `).join("")}
      </div>
    </section>
    ${renderModule("Pedagógico", [
      ["Diário de classe", "Lançamento de notas, frequência, avaliações e recuperação paralela.", ["Notas", "Frequência", "Recuperação"]],
      ["Planejamento", "Planos de aula, registro de atividades, materiais e acompanhamento de habilidades.", ["Aulas", "Atividades", "BNCC"]],
      ["Indicadores", "Gráficos de rendimento, aprendizagem, turma e escola.", ["Rendimento", "Aprendizagem", "Relatórios"]],
    ])}
  `;
}

function renderSecretaria() {
  return renderModule("Secretaria", [
    ["Documentos escolares", "Boletins, históricos, atas, declarações e relatórios com trilha de emissão.", ["Boletins", "Históricos", "Atas"]],
    ["Matrículas", "Gestão de matrícula, rematrícula, transferência interna e externa.", ["Matrícula", "Rematrícula", "Transferência"]],
    ["Relatórios exportáveis", "Relatórios por turma, escola, matrícula e frequência em PDF e Excel.", ["Turma", "Escola", "Personalizados"]],
  ]);
}

function renderAva() {
  return renderModule("AVA", [
    ["Salas virtuais", "Organize turmas, videoaulas, materiais em PDF e biblioteca digital.", ["Videoaulas", "PDF", "Biblioteca"]],
    ["Atividades online", "Questionários, entrega de trabalhos e correção automática de exercícios objetivos.", ["Questionários", "Trabalhos", "Correção automática"]],
    ["Participação", "Registro de acesso, fóruns, interações e desempenho no ambiente virtual.", ["Fóruns", "Participação", "Desempenho"]],
  ]);
}

function renderCenso() {
  return `
    <section class="panel">
      <div class="panel-header">
        <div><p class="eyebrow">Censo Escolar</p><h2>Conferência prévia</h2></div>
        <button class="primary-action">Exportar layout oficial</button>
      </div>
      <div class="split-list">
        ${[
          ["Dados cadastrais", 96],
          ["Vínculos de matrícula", 91],
          ["Docentes e turmas", 88],
          ["Infraestrutura escolar", 94],
        ].map(([label, value]) => `
          <div class="module-card">
            <strong>${label}</strong>
            <p>${value}% validado antes da exportação automática.</p>
            <div class="progress"><span style="width:${value}%"></span></div>
          </div>
        `).join("")}
      </div>
    </section>
    ${renderModule("Integração", [
      ["Exportação", "Geração automática de arquivos nos layouts exigidos pelo Censo Escolar.", ["Layouts oficiais", "Conferência", "Histórico"]],
      ["Validação", "Regras para inconsistências, campos obrigatórios e vínculos inválidos.", ["Inconsistências", "Pendências", "Correções"]],
      ["Importação", "Recepção de arquivos oficiais e relatórios de acompanhamento.", ["Arquivos oficiais", "Protocolos", "Acompanhamento"]],
    ])}
  `;
}

function renderComunicacao() {
  return renderModule("Comunicação", [
    ["Notificações", "Central de avisos para alunos, professores, responsáveis e gestores.", ["Avisos", "Prioridades", "Leitura"]],
    ["Mensagens internas", "Comunicação por turma, escola, perfil ou destinatário individual.", ["Turma", "Escola", "Perfil"]],
    ["Comprovantes", "Registro de leitura, alcance de comunicados e auditoria de envio.", ["Leitura", "Alcance", "Auditoria"]],
  ]);
}

function renderRelatorios() {
  return `
    <section class="panel">
      <div class="panel-header">
        <div><p class="eyebrow">Catálogo BI</p><h2>Relatórios gerenciais</h2></div>
        <div class="filters"><button class="chip active">PDF</button><button class="chip">Excel</button><button class="chip">Painel</button></div>
      </div>
      <div class="module-grid">
        ${["Matrículas", "Frequência", "Rendimento", "Censo Escolar", "Evasão", "Documentos", "Comunicação", "Professores", "Turmas"].map((name, index) => `
          <article class="module-card">
            <strong>${name}</strong>
            <p>${12 + index} relatórios com filtros por escola, turma, período e situação.</p>
            <button class="secondary-action">Abrir catálogo</button>
          </article>
        `).join("")}
      </div>
    </section>
  `;
}

function renderSeguranca() {
  return renderModule("Infraestrutura técnica", [
    ["Autenticação", "Perfis de acesso, senhas criptografadas e segregação por município, escola e função.", ["RBAC", "Criptografia", "Sessões seguras"]],
    ["Auditoria e LGPD", "Logs, consentimentos, bases legais, minimização e rastreabilidade de dados.", ["Logs", "LGPD", "Retenção"]],
    ["Nuvem e continuidade", "API REST, banco relacional, backup diário, monitoramento e alta disponibilidade.", ["API REST", "Backup", "Monitoramento"]],
  ]);
}

function setView(viewName) {
  const view = views[viewName] || views.dashboard;
  viewTitle.textContent = view.title;
  viewSubtitle.textContent = view.subtitle;
  mainColumn.innerHTML = view.render();
  document.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("active", item.dataset.view === viewName));
  sidebar.classList.remove("open");
}

function normalizeUser(user) {
  if (!user) return null;
  const roles = Array.isArray(user.roles) ? user.roles : [user.role].filter(Boolean);
  return {
    name: user.name,
    email: user.email,
    cpf: user.cpf,
    roles,
    school: user.school || "Rede municipal",
  };
}

async function authenticateUser(cpf, password) {
  if (supabaseConfig.url && supabaseConfig.anonKey && window.supabase) {
    const client = window.supabase.createClient(supabaseConfig.url, supabaseConfig.anonKey);
    const userResponse = await client
      .from(supabaseConfig.tables.users)
      .select("id, nome, email, cpf")
      .eq("cpf", cpf)
      .single();
    if (userResponse.error) throw new Error("CPF não encontrado.");
    const result = await client.auth.signInWithPassword({ email: userResponse.data.email, password });
    if (result.error) throw new Error("Senha incorreta para o CPF informado.");
    const roleResponse = await client
      .from(supabaseConfig.tables.roles)
      .select("cargo, escola")
      .eq("usuario_id", result.data.user.id);
    if (roleResponse.error) throw new Error(roleResponse.error.message);
    return normalizeUser({
      name: userResponse.data.nome || result.data.user.user_metadata?.name || userResponse.data.email,
      email: userResponse.data.email,
      cpf: userResponse.data.cpf,
      roles: roleResponse.data.map((item) => item.cargo),
      school: roleResponse.data[0]?.escola,
    });
  }

  try {
    const response = await fetch("/api/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ cpf, password }),
    });
    if (response.ok) {
      return normalizeUser(await response.json());
    }
    const errorPayload = await response.json().catch(() => ({}));
    throw new Error(errorPayload.error || "CPF ou senha incorretos.");
  } catch (error) {
    apiAvailable = false;
    if (error.message) throw error;
  }

  throw new Error("Não foi possível validar o acesso. Verifique a API ou a conexão com o Supabase.");
}

function showLogin(message = "") {
  appShell.hidden = true;
  loginScreen.hidden = false;
  document.body.classList.remove("is-authenticated");
  loginFeedback.textContent = message;
  rolePicker.hidden = true;
  pendingLoginUser = null;
}

function showRolePicker(user) {
  pendingLoginUser = user;
  rolePicker.hidden = false;
  roleOptions.innerHTML = user.roles.map((role) => `
    <button class="role-option" type="button" data-role="${role}">
      <strong>${role}</strong>
      <span>${roleToProfile[role] || role}</span>
    </button>
  `).join("");
  loginFeedback.textContent = `${user.name}, encontramos mais de um cargo cadastrado para você.`;
}

function showFormAlert(message) {
  formAlert.querySelector("p").textContent = message;
  formAlert.hidden = false;
}

function hideFormAlert() {
  formAlert.hidden = true;
  formAlert.querySelector("p").textContent = "";
}

function configureProfileOptions(session) {
  const profiles = session.activeProfile === "Administrador"
    ? allProfiles
    : session.roles.map((role) => roleToProfile[role] || role).filter((profile) => profileToView[profile]);
  profileSelect.innerHTML = profiles.map((profile) => `<option>${profile}</option>`).join("");
}

function completeLogin(user, selectedRole) {
  const profile = roleToProfile[selectedRole] || selectedRole;
  const session = { ...user, activeRole: selectedRole, activeProfile: profile };
  sessionStorage.setItem("sigaeSession", JSON.stringify(session));
  loginScreen.hidden = true;
  appShell.hidden = false;
  document.body.classList.add("is-authenticated");
  configureProfileOptions(session);
  if ([...profileSelect.options].some((option) => option.value === profile)) {
    profileSelect.value = profile;
  }
  setView(profileToView[profile] || "dashboard");
}

function renderSidebars() {
  document.querySelector("#alertsList").innerHTML = alerts.map(([title, text]) => `
    <div class="timeline-item"><strong>${title}</strong><span>${text}</span></div>
  `).join("");
  document.querySelector("#activityList").innerHTML = activities.map(([title, text]) => `
    <div class="activity-item"><strong>${title}</strong><span>${text}</span></div>
  `).join("");
}

document.querySelectorAll(".nav-item").forEach((item) => {
  item.addEventListener("click", () => setView(item.dataset.view));
});

document.querySelector("#menuButton").addEventListener("click", () => {
  sidebar.classList.toggle("open");
});

document.querySelector("#newRecordButton").addEventListener("click", () => {
  document.querySelector("#recordDialog").showModal();
});

document.querySelector("#logoutButton").addEventListener("click", () => {
  sessionStorage.removeItem("sigaeSession");
  showLogin("Sessão encerrada com segurança.");
});

document.querySelector("#forgotPasswordButton").addEventListener("click", () => {
  loginFeedback.textContent = "Informe seu CPF e solicite a recuperação à secretaria do sistema.";
});

document.querySelector("#loginCpf").addEventListener("input", (event) => {
  event.target.value = event.target.value.replace(/\D/g, "").slice(0, 11);
  hideFormAlert();
});

document.querySelector("#loginPassword").addEventListener("input", () => {
  hideFormAlert();
});

document.querySelector("#passwordToggle").addEventListener("click", () => {
  const passwordInput = document.querySelector("#loginPassword");
  const toggle = document.querySelector("#passwordToggle");
  const isVisible = passwordInput.type === "text";
  passwordInput.type = isVisible ? "password" : "text";
  toggle.classList.toggle("is-visible", !isVisible);
  toggle.setAttribute("aria-pressed", String(!isVisible));
  toggle.setAttribute("aria-label", isVisible ? "Mostrar senha" : "Ocultar senha");
  passwordInput.focus();
});

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  hideFormAlert();
  loginFeedback.textContent = "Verificando cadastro...";
  rolePicker.hidden = true;
  const cpf = document.querySelector("#loginCpf").value.replace(/\D/g, "");
  const password = document.querySelector("#loginPassword").value;
  try {
    if (!cpf) {
      showFormAlert("Preencha o CPF para continuar.");
      loginFeedback.textContent = "";
      return;
    }
    if (cpf.length !== 11) {
      showFormAlert("Informe um CPF com 11 números.");
      loginFeedback.textContent = "";
      return;
    }
    if (!password) {
      showFormAlert("Preencha a senha para continuar.");
      loginFeedback.textContent = "";
      return;
    }
    const user = await authenticateUser(cpf, password);
    if (user.roles.length > 1) {
      showRolePicker(user);
      return;
    }
    completeLogin(user, user.roles[0]);
  } catch (error) {
    showFormAlert(error.message || "Não foi possível entrar agora.");
    loginFeedback.textContent = "";
  }
});

roleOptions.addEventListener("click", (event) => {
  const button = event.target.closest(".role-option");
  if (!button || !pendingLoginUser) return;
  completeLogin(pendingLoginUser, button.dataset.role);
});

document.querySelector("#recordForm").addEventListener("submit", (event) => {
  const submitter = event.submitter;
  if (submitter && submitter.value === "cancel") return;
  event.preventDefault();
  const record = {
    type: document.querySelector("#recordType").value,
    name: document.querySelector("#recordName").value.trim(),
    school: document.querySelector("#recordSchool").value,
    status: document.querySelector("#recordStatus").value,
  };
  if (!record.name) return;
  records.push(record);
  localStorage.setItem("sigaeRecords", JSON.stringify(records));
  if (apiAvailable) {
    fetch("/api/records", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(record),
    }).catch(() => {});
  }
  document.querySelector("#recordForm").reset();
  document.querySelector("#recordDialog").close();
  setView("administrativo");
});

searchInput.addEventListener("input", () => {
  const term = searchInput.value.trim().toLowerCase();
  if (!term) {
    setView(document.querySelector(".nav-item.active").dataset.view);
    return;
  }
  const foundSchools = schools.filter((school) => school.name.toLowerCase().includes(term));
  const foundStudents = students.filter((student) => `${student.name} ${student.school} ${student.class}`.toLowerCase().includes(term));
  mainColumn.innerHTML = `
    <section class="panel">
      <div class="panel-header"><div><p class="eyebrow">Busca global</p><h2>Resultados para "${term}"</h2></div></div>
      <div class="module-grid">
        ${foundSchools.map((school) => `<article class="module-card"><strong>${school.name}</strong><p>${school.students} alunos, ${school.teachers} professores, frequência ${school.attendance}%.</p>${badge(school.status)}</article>`).join("")}
        ${foundStudents.map((student) => `<article class="module-card"><strong>${student.name}</strong><p>${student.school} - ${student.class}. Nota ${student.grade}, frequência ${student.attendance}.</p>${badge(student.status)}</article>`).join("")}
        ${foundSchools.length + foundStudents.length === 0 ? "<article class=\"module-card\"><strong>Nenhum resultado</strong><p>Tente buscar por escola, aluno, turma ou módulo.</p></article>" : ""}
      </div>
    </section>
  `;
});

profileSelect.addEventListener("change", (event) => {
  const profile = event.target.value;
  setView(profileToView[profile] || "dashboard");
});

async function hydrateFromApi() {
  try {
    const response = await fetch("/api/dashboard");
    if (!response.ok) return;
    const data = await response.json();
    if (Array.isArray(data.schools)) {
      schools = data.schools;
      apiAvailable = true;
    }
  } catch (error) {
    apiAvailable = false;
  }
}

renderSidebars();
hydrateFromApi().finally(() => {
  const savedSession = JSON.parse(sessionStorage.getItem("sigaeSession") || "null");
  if (savedSession) {
    completeLogin(savedSession, savedSession.activeRole);
  } else {
    showLogin();
  }
});
