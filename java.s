const STORE_KEY = "casino-world-backend";
const MEMBER_KEY = "casino-world-member";
const REF_KEY = "casino-world-ref";

const readStore = () => {
    const empty = { members: [], transactions: [], partners: [] };
    try {
        const saved = JSON.parse(localStorage.getItem(STORE_KEY));
        if (saved && Array.isArray(saved.members) && Array.isArray(saved.transactions) && Array.isArray(saved.partners)) {
            return saved;
        }
    } catch (error) {
        return empty;
    }
    return empty;
};

const writeStore = (store) => {
    localStorage.setItem(STORE_KEY, JSON.stringify(store));
};

const currentMember = (store) => {
    return store.members.find((member) => member.id === sessionStorage.getItem(MEMBER_KEY));
};

const dayKey = (value) => {
    const date = new Date(value);
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return date.getFullYear() + "-" + month + "-" + day;
};

const packageAmount = (label) => {
    const match = String(label).replace(/,/g, "").match(/(\d+(?:\.\d+)?)/);
    return match ? Number(match[1]) : 0;
};

const refParam = new URLSearchParams(window.location.search).get("ref");
if (refParam) {
    sessionStorage.setItem(REF_KEY, refParam.trim());
}

const textCell = (value) => {
    const cell = document.createElement("td");
    cell.textContent = value;
    return cell;
};

const stackCell = (primary, secondary, primaryClass, secondaryClass) => {
    const cell = document.createElement("td");
    cell.append(Object.assign(document.createElement("span"), { className: primaryClass, textContent: primary }));
    if (secondary) {
        cell.append(Object.assign(document.createElement("span"), { className: secondaryClass, textContent: secondary }));
    }
    return cell;
};

const statusBadge = (status) => {
    const badge = document.createElement("span");
    const paid = status === "PAID";
    badge.className = paid ? "badge-paid" : "badge-unpaid";
    badge.textContent = paid ? "PAID" : "UNPAID";
    return badge;
};

const renderBackend = () => {
    if (!document.getElementById("panel-members")) {
        return;
    }
    const store = readStore();
    const paid = store.transactions.filter((item) => item.status === "PAID");
    const today = dayKey(new Date());
    const sumFor = (country, onlyToday) => {
        return paid
            .filter((item) => (item.country === "ngn" ? "ngn" : "gh") === country)
            .filter((item) => !onlyToday || dayKey(item.date) === today)
            .reduce((total, item) => total + packageAmount(item.package), 0);
    };
    const connected = store.members.filter((member) => member.phone).length;
    const membersAmount = document.getElementById("stat-members");
    if (membersAmount) {
        membersAmount.textContent = String(store.members.length);
        document.getElementById("stat-members-note").textContent = connected + " connected account" + (connected === 1 ? "" : "s");
        document.getElementById("stat-daily-gh").textContent = String(sumFor("gh", true));
        document.getElementById("stat-total-gh").textContent = String(sumFor("gh", false));
        document.getElementById("stat-daily-ng").textContent = "₦" + sumFor("ngn", true);
        document.getElementById("stat-total-ng").textContent = "₦" + sumFor("ngn", false);
    }
    document.querySelectorAll(".revenue-table[data-country]").forEach((table) => {
        const country = table.dataset.country;
        const prefix = country === "ngn" ? "NGN " : "GHS ";
        table.querySelectorAll("[data-day]").forEach((row) => {
            const total = paid
                .filter((item) => (item.country === "ngn" ? "ngn" : "gh") === country && dayKey(item.date) === row.dataset.day)
                .reduce((sum, item) => sum + packageAmount(item.package), 0);
            row.querySelector(".revenue-amount").textContent = prefix + total;
        });
    });

    const memberBody = document.querySelector("#panel-members .members tbody");
    memberBody.replaceChildren();
    store.members.forEach((member) => {
        const joined = new Date(member.joined);
        const row = document.createElement("tr");
        row.dataset.search = [member.name, member.email, member.referredBy].join(" ").toLowerCase();
        const status = document.createElement("td");
        status.append(statusBadge(member.status));
        const referred = document.createElement("td");
        if (member.referredBy) {
            referred.append(Object.assign(document.createElement("span"), { className: "referral-pill", textContent: member.referredBy }));
        } else {
            referred.textContent = "—";
        }
        row.append(
            stackCell(member.name, member.email, "member-name", "member-email"),
            stackCell(joined.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }), joined.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }), "joined-date", "joined-time"),
            status,
            referred
        );
        memberBody.append(row);
    });
    document.getElementById("members-empty").hidden = store.members.length !== 0;

    const transactionBody = document.querySelector("#panel-transactions .members tbody");
    transactionBody.replaceChildren();
    store.transactions.forEach((item) => {
        const when = new Date(item.date);
        const row = document.createElement("tr");
        row.dataset.search = [item.name, item.email, item.package, item.proof].join(" ").toLowerCase();
        const proof = textCell(item.proof || "—");
        const referral = document.createElement("td");
        if (item.referral) {
            referral.append(Object.assign(document.createElement("span"), { className: "referral-pill", textContent: item.referral }));
        } else {
            referral.textContent = "—";
        }
        const status = document.createElement("td");
        if (item.status === "PAID") {
            status.append(statusBadge("PAID"));
        } else {
            const confirm = document.createElement("button");
            confirm.type = "button";
            confirm.className = "copy";
            confirm.textContent = "Confirm";
            confirm.addEventListener("click", () => {
                const next = readStore();
                const saved = next.transactions.find((entry) => entry.id === item.id);
                if (!saved) {
                    return;
                }
                saved.status = "PAID";
                const member = next.members.find((entry) => entry.email.toLowerCase() === saved.email.toLowerCase());
                if (member) {
                    member.status = "PAID";
                }
                writeStore(next);
                renderBackend();
            });
            status.append(confirm);
        }
        row.append(
            stackCell(when.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }), when.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }), "joined-date", "joined-time"),
            stackCell(item.name || "—", item.email, "member-name", "member-email"),
            textCell(item.package || "—"),
            proof,
            referral,
            status
        );
        transactionBody.append(row);
    });
    document.getElementById("transactions-empty").hidden = store.transactions.length !== 0;

    const partnerBody = document.querySelector("#panel-partners .members tbody");
    partnerBody.replaceChildren();
    store.partners.forEach((partner) => {
        const row = document.createElement("tr");
        row.dataset.search = [partner.name, partner.email, partner.referral].join(" ").toLowerCase();
        const code = document.createElement("td");
        if (partner.referral) {
            code.append(Object.assign(document.createElement("span"), { className: "referral-pill", textContent: partner.referral }));
        } else {
            code.textContent = "—";
        }
        const referredPaid = paid.filter((item) => partner.referral && item.referral === partner.referral);
        const ghs = referredPaid.filter((item) => item.country !== "ngn").reduce((total, item) => total + packageAmount(item.package), 0);
        const ngn = referredPaid.filter((item) => item.country === "ngn").reduce((total, item) => total + packageAmount(item.package), 0);
        row.append(
            stackCell(partner.name, partner.email, "member-name", "member-email"),
            textCell("Active"),
            code,
            textCell(partner.referral ? "index.html?ref=" + encodeURIComponent(partner.referral) : "—"),
            textCell("—"),
            textCell("GHS " + ghs),
            textCell("NGN " + ngn),
            textCell("—")
        );
        partnerBody.append(row);
    });
    document.getElementById("partners-empty").hidden = store.partners.length !== 0;
    ["member-search", "transaction-search", "partner-search"].forEach((id) => {
        const input = document.getElementById(id);
        if (input && input.value) {
            input.dispatchEvent(new Event("input"));
        }
    });
};

const adminNav = document.querySelector(".admin-nav");
if (adminNav) {
    const panelButtons = adminNav.querySelectorAll("[data-panel]");
    const panels = {
        overview: document.getElementById("panel-overview"),
        members: document.getElementById("panel-members"),
        transactions: document.getElementById("panel-transactions"),
        partners: document.getElementById("panel-partners")
    };

    const openPanel = (name) => {
        if (!panels[name]) {
            return;
        }
        panelButtons.forEach((button) => {
            button.classList.toggle("is-on", button.dataset.panel === name);
        });
        Object.entries(panels).forEach(([key, panel]) => {
            panel.hidden = key !== name;
        });
    };

    panelButtons.forEach((button) => {
        button.addEventListener("click", () => {
            openPanel(button.dataset.panel);
        });
    });

    const requested = window.location.hash.replace("#", "");
    if (panels[requested]) {
        openPanel(requested);
    }
}

const filterRows = (input, panelId, emptyId) => {
    const query = input.value.trim().toLowerCase();
    const rows = document.querySelectorAll("#" + panelId + " .members tbody tr");
    let shown = 0;
    rows.forEach((row) => {
        const match = (row.dataset.search || "").includes(query);
        row.hidden = !match;
        if (match) {
            shown += 1;
        }
    });
    const empty = document.getElementById(emptyId);
    empty.hidden = shown !== 0;
};

const memberSearch = document.getElementById("member-search");
if (memberSearch) {
    memberSearch.addEventListener("input", () => {
        filterRows(memberSearch, "panel-members", "members-empty");
    });
}

const transactionSearch = document.getElementById("transaction-search");
if (transactionSearch) {
    transactionSearch.addEventListener("input", () => {
        filterRows(transactionSearch, "panel-transactions", "transactions-empty");
    });
}

const addPartnerForm = document.getElementById("add-partner-form");
if (addPartnerForm) {
    addPartnerForm.addEventListener("submit", (event) => {
        event.preventDefault();
        const data = new FormData(addPartnerForm);
        const name = String(data.get("name")).trim();
        const email = String(data.get("email")).trim();
        const password = String(data.get("password"));
        const referral = String(data.get("referral")).trim();
        if (!password) {
            return;
        }
        const store = readStore();
        store.partners.unshift({
            id: Date.now().toString(36),
            name,
            email,
            referral
        });
        writeStore(store);
        addPartnerForm.reset();
        renderBackend();
    });
}

const partnerSearch = document.getElementById("partner-search");
if (partnerSearch) {
    partnerSearch.addEventListener("input", () => {
        filterRows(partnerSearch, "panel-partners", "partners-empty");
    });
}

const partnerTabs = document.querySelectorAll("[data-partner-tab]");
if (partnerTabs.length) {
    const partnerForms = {
        "sign-in": document.getElementById("partner-sign-in"),
        join: document.getElementById("partner-join")
    };
    partnerTabs.forEach((tab) => {
        tab.addEventListener("click", () => {
            const name = tab.dataset.partnerTab;
            partnerTabs.forEach((item) => {
                item.classList.toggle("is-on", item === tab);
            });
            Object.entries(partnerForms).forEach(([key, form]) => {
                form.hidden = key !== name;
            });
        });
    });
    const partnerSignIn = partnerForms["sign-in"];
    const partnerJoin = partnerForms.join;
    partnerSignIn.addEventListener("submit", (event) => {
        event.preventDefault();
        window.location.href = "partner.html";
    });
    partnerJoin.addEventListener("submit", (event) => {
        event.preventDefault();
    });

    const partnerStart = window.location.hash.replace("#", "");
    const startTab = document.querySelector('[data-partner-tab="' + partnerStart + '"]');
    if (startTab) {
        startTab.click();
    }
}

const partnerDashNav = document.getElementById("partner-dash-nav");
if (partnerDashNav) {
    const dashButtons = partnerDashNav.querySelectorAll("[data-partner-panel]");
    const dashPanels = {
        overview: document.getElementById("partner-panel-overview"),
        referrals: document.getElementById("partner-panel-referrals")
    };
    const openDash = (name) => {
        if (!dashPanels[name]) {
            return;
        }
        dashButtons.forEach((button) => {
            button.classList.toggle("is-on", button.dataset.partnerPanel === name);
        });
        Object.entries(dashPanels).forEach(([key, panel]) => {
            panel.hidden = key !== name;
        });
    };
    dashButtons.forEach((button) => {
        button.addEventListener("click", () => {
            openDash(button.dataset.partnerPanel);
        });
    });
    const dashStart = window.location.hash.replace("#", "");
    if (dashPanels[dashStart]) {
        openDash(dashStart);
    }
}

const referralSearch = document.getElementById("referral-search");
if (referralSearch) {
    const referralRows = document.querySelectorAll("#partner-panel-referrals .members tbody tr");
    const referralsEmpty = document.getElementById("referrals-empty");
    referralSearch.addEventListener("input", () => {
        const query = referralSearch.value.trim().toLowerCase();
        let shown = 0;
        referralRows.forEach((row) => {
            const match = row.dataset.search.includes(query);
            row.hidden = !match;
            if (match) {
                shown += 1;
            }
        });
        referralsEmpty.hidden = shown !== 0;
    });
}

const loginForm = document.getElementById("login-form");
if (loginForm) {
    loginForm.addEventListener("submit", (event) => {
        event.preventDefault();
        const email = String(new FormData(loginForm).get("email")).trim().toLowerCase();
        const store = readStore();
        const member = store.members.find((item) => item.email.toLowerCase() === email);
        if (member) {
            sessionStorage.setItem(MEMBER_KEY, member.id);
        }
        window.location.href = "country.html";
    });
}

const signupForm = document.getElementById("signup-form");
if (signupForm) {
    signupForm.addEventListener("submit", (event) => {
        event.preventDefault();
        const data = new FormData(signupForm);
        const name = String(data.get("full-name")).trim();
        const email = String(data.get("email")).trim();
        const store = readStore();
        let member = store.members.find((item) => item.email.toLowerCase() === email.toLowerCase());
        if (!member) {
            member = {
                id: Date.now().toString(36),
                name,
                email,
                joined: new Date().toISOString(),
                phone: "",
                country: "",
                status: "UNPAID",
                referredBy: sessionStorage.getItem(REF_KEY) || ""
            };
            store.members.unshift(member);
        } else {
            member.name = name;
        }
        writeStore(store);
        sessionStorage.setItem(MEMBER_KEY, member.id);
        window.location.href = "country.html";
    });
}

const copyNumber = document.getElementById("copy-number");
if (copyNumber) {
    copyNumber.addEventListener("click", () => {
        const number = document.getElementById("momo-number").textContent.trim();
        const done = () => {
            copyNumber.textContent = "COPIED";
            window.setTimeout(() => {
                copyNumber.textContent = "COPY";
            }, 1500);
        };
        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(number).then(done);
            return;
        }
        const area = document.createElement("textarea");
        area.value = number;
        area.setAttribute("readonly", "");
        area.style.position = "fixed";
        area.style.left = "-9999px";
        document.body.appendChild(area);
        area.select();
        document.execCommand("copy");
        area.remove();
        done();
    });
}

const receipt = document.getElementById("receipt");
const receiptTitle = document.getElementById("receipt-title");
const receiptZone = document.getElementById("receipt-zone");
if (receipt && receiptTitle && receiptZone) {
    const showFile = () => {
        const file = receipt.files && receipt.files[0];
        receiptTitle.textContent = file ? file.name : "Choose a screenshot";
        receiptZone.classList.toggle("has-file", Boolean(file));
    };

    receipt.addEventListener("change", showFile);
    ["dragover", "dragenter"].forEach((name) => {
        receiptZone.addEventListener(name, (event) => {
            event.preventDefault();
            receiptZone.classList.add("is-drag");
        });
    });
    ["dragleave", "drop"].forEach((name) => {
        receiptZone.addEventListener(name, (event) => {
            event.preventDefault();
            receiptZone.classList.remove("is-drag");
        });
    });
    receiptZone.addEventListener("drop", (event) => {
        if (!event.dataTransfer || !event.dataTransfer.files.length) {
            return;
        }
        receipt.files = event.dataTransfer.files;
        showFile();
    });
}

const GATEWAY_KEY = "casino-world-gateways";
const gatewayGroups = {
    momo: ["network", "number", "name"],
    bank: ["bank", "account", "name"]
};

const readGateways = () => {
    try {
        const saved = JSON.parse(localStorage.getItem(GATEWAY_KEY));
        if (saved && saved.momo && saved.bank) {
            return saved;
        }
    } catch (error) {
        return null;
    }
    return null;
};

const ghanaNetworks = ["MTN MoMo", "Telecel Cash", "AirtelTigo Money"];
const nigeriaBanks = ["Access Bank", "GTBank", "Zenith Bank", "First Bank", "UBA", "OPay", "PalmPay", "Kuda", "Moniepoint", "Fidelity Bank", "FCMB", "Sterling Bank", "Wema Bank", "Union Bank", "Ecobank", "Stanbic IBTC", "Polaris Bank", "Providus Bank"];

const fillChoices = (node, names) => {
    node.replaceChildren();
    names.forEach((name) => {
        const line = document.createElement("span");
        line.textContent = name;
        node.append(line);
    });
};

const paymentForm = document.getElementById("payment-form");
const applyPayDetails = () => {
    const numberNode = document.getElementById("momo-number");
    if (!numberNode) {
        return;
    }
    const savedGateways = readGateways();
    const payNgn = new URLSearchParams(window.location.search).get("pay") === "ngn";
    const slot = (name) => document.querySelector('.momo-row[data-slot="' + name + '"] .value');
    const networkValue = slot("network");
    const nameValue = slot("name");
    const payNetwork = document.querySelector(".pay-network");
    if (payNgn) {
        const bank = savedGateways ? savedGateways.bank : { bank: "", account: "", name: "" };
        if (networkValue) {
            if (bank.bank) {
                networkValue.textContent = bank.bank;
            } else {
                fillChoices(networkValue, nigeriaBanks);
            }
        }
        numberNode.textContent = bank.account || "Account number";
        if (nameValue) {
            nameValue.textContent = bank.name || "Account name";
        }
        if (payNetwork) {
            payNetwork.textContent = bank.bank || "any of the banks above";
        }
        const networkLabel = document.querySelector('.momo-row[data-slot="network"] .label');
        const numberLabel = document.querySelector('.momo-row[data-slot="number"] .label');
        if (networkLabel) {
            networkLabel.textContent = "BANK";
        }
        if (numberLabel) {
            numberLabel.textContent = "ACCOUNT";
        }
        const top = document.querySelector(".momo-top span");
        if (top) {
            top.textContent = "BANK TRANSFER";
        }
        const heading = document.querySelector(".momo-card h1");
        if (heading) {
            heading.textContent = "Pay by bank transfer";
        }
        return;
    }
    if (!savedGateways) {
        return;
    }
    const momo = savedGateways.momo;
    if (networkValue) {
        if (momo.network) {
            networkValue.textContent = momo.network;
        } else {
            fillChoices(networkValue, ghanaNetworks);
        }
    }
    numberNode.textContent = momo.number || "MoMo number";
    if (nameValue) {
        nameValue.textContent = momo.name || "Account name";
    }
    if (payNetwork) {
        payNetwork.textContent = momo.network || "MTN MoMo, Telecel Cash, or AirtelTigo Money";
    }
};
if (paymentForm) {
    const payNgn = new URLSearchParams(window.location.search).get("pay") === "ngn";
    applyPayDetails();
    window.addEventListener("storage", (event) => {
        if (event.key === GATEWAY_KEY) {
            applyPayDetails();
        }
    });
    if (payNgn) {
        const naira = (ghs) => {
            const amount = Math.round(Number(ghs) * 119.64 * 100) / 100;
            return "₦" + amount.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        };
        document.querySelectorAll(".amount, .green").forEach((node) => {
            node.textContent = node.textContent.replace(/GHS\s+(\d+)/, (full, ghs) => naira(ghs));
        });
        const close = document.querySelector(".momo-top a");
        if (close) {
            close.href = "packageN.html";
        }
        paymentForm.action = "packageN.html";
    }
    const packageLabel = document.querySelector(".amount").textContent.trim();
    const statusNote = document.createElement("p");
    statusNote.id = "payment-status";
    statusNote.hidden = true;
    paymentForm.before(statusNote);

    const matchingPayment = () => {
        const store = readStore();
        const member = currentMember(store);
        const email = member ? member.email.toLowerCase() : "";
        return store.transactions.find((item) => item.package === packageLabel && item.email.toLowerCase() === email);
    };

    const showPaymentState = () => {
        const saved = matchingPayment();
        if (!saved) {
            return;
        }
        paymentForm.hidden = true;
        statusNote.hidden = false;
        statusNote.textContent = saved.status === "PAID" ? "Payment confirmed." : "Waiting for admin confirmation.";
    };

    paymentForm.addEventListener("submit", (event) => {
        event.preventDefault();
        const store = readStore();
        const member = currentMember(store);
        const proofFile = receipt && receipt.files ? receipt.files[0] : null;
        store.transactions.unshift({
            id: Date.now().toString(36),
            date: new Date().toISOString(),
            name: member ? member.name : "",
            email: member ? member.email : "",
            package: packageLabel,
            proof: proofFile ? proofFile.name : "",
            referral: member ? member.referredBy : (sessionStorage.getItem(REF_KEY) || ""),
            status: "PENDING",
            country: member && member.country === "ngn" ? "ngn" : "gh"
        });
        writeStore(store);
        showPaymentState();
    });
    window.addEventListener("storage", showPaymentState);
    showPaymentState();
}

const connectForm = document.getElementById("connect-form");
if (connectForm) {
    const countries = {
        ngn: { dial: "+234", placeholder: "801 234 5678", flag: "flag-ngn" },
        gh: { dial: "+233", placeholder: "24 123 4567", flag: "flag-gh" }
    };
    const chosen = new URLSearchParams(window.location.search).get("country");
    const country = countries[chosen] ? chosen : "ngn";
    const details = countries[country];

    document.getElementById("country").value = country;
    document.getElementById("dial-label").textContent = details.dial;
    document.getElementById("phone").placeholder = details.placeholder;
    document.getElementById("flag-ngn").hidden = details.flag !== "flag-ngn";
    document.getElementById("flag-gh").hidden = details.flag !== "flag-gh";
    connectForm.action = country === "ngn" ? "packageN.html" : "plist.html";

    connectForm.addEventListener("submit", (event) => {
        event.preventDefault();
        const store = readStore();
        const member = currentMember(store);
        if (member) {
            member.country = country;
            member.phone = details.dial + " " + String(new FormData(connectForm).get("phone")).trim();
            writeStore(store);
        }
        window.location.href = connectForm.action;
    });
}

const countryForm = document.querySelector('form[action="connecting.html"]');
if (countryForm) {
    countryForm.addEventListener("submit", (event) => {
        const chosenCountry = event.submitter ? event.submitter.value : "";
        const store = readStore();
        const member = currentMember(store);
        if (member && (chosenCountry === "gh" || chosenCountry === "ngn")) {
            member.country = chosenCountry;
            writeStore(store);
        }
    });
}

const adminRefresh = document.getElementById("admin-refresh");
if (adminRefresh) {
    adminRefresh.addEventListener("click", () => {
        renderBackend();
    });
}

renderBackend();

const adminLock = document.getElementById("admin-lock");
if (adminLock) {
    const adminHeader = document.querySelector(".admin-header");
    const adminMain = document.querySelector(".admin-main");
    const adminError = document.getElementById("admin-lock-error");
    const openAdmin = () => {
        sessionStorage.setItem("casino-world-admin", "open");
        adminLock.hidden = true;
        adminHeader.hidden = false;
        adminMain.hidden = false;
    };
    if (sessionStorage.getItem("casino-world-admin") === "open") {
        openAdmin();
    }
    document.getElementById("admin-lock-form").addEventListener("submit", (event) => {
        event.preventDefault();
        const code = String(new FormData(event.currentTarget).get("code")).trim();
        if (code === "054391") {
            openAdmin();
        } else {
            adminError.hidden = false;
        }
    });
    const lockAgain = document.getElementById("admin-lock-again");
    if (lockAgain) {
        lockAgain.addEventListener("click", () => {
            sessionStorage.removeItem("casino-world-admin");
            window.location.reload();
        });
    }
    const saveGateways = document.getElementById("save-gateways");
    if (saveGateways) {
        const savedGateways = readGateways();
        const presetMomo = {
            network: "Telecel Cash",
            number: "0502352531",
            name: "Patrick Agbavitor"
        };
        if (savedGateways) {
            const momo = savedGateways.momo;
            const stillPreset = momo.network === presetMomo.network
                && momo.number === presetMomo.number
                && momo.name === presetMomo.name;
            if (stillPreset) {
                savedGateways.momo = { network: "", number: "", name: "" };
                localStorage.setItem(GATEWAY_KEY, JSON.stringify(savedGateways));
            }
            Object.entries(gatewayGroups).forEach(([group, fields]) => {
                fields.forEach((field) => {
                    const input = document.getElementById(group + "-" + field);
                    if (input && typeof savedGateways[group][field] === "string") {
                        input.value = savedGateways[group][field];
                    }
                });
            });
        }
        saveGateways.addEventListener("click", () => {
            const next = { momo: {}, bank: {} };
            Object.entries(gatewayGroups).forEach(([group, fields]) => {
                fields.forEach((field) => {
                    const input = document.getElementById(group + "-" + field);
                    next[group][field] = input ? input.value.trim() : "";
                });
            });
            localStorage.setItem(GATEWAY_KEY, JSON.stringify(next));
            const note = document.getElementById("gateway-saved");
            note.hidden = false;
        });
    }
}

const predictionFeed = document.querySelector(".feed");
if (predictionFeed) {
    const liveOdds = predictionFeed.querySelectorAll(".feed-odd");
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.setInterval(() => {
        const odd = liveOdds[Math.floor(Math.random() * liveOdds.length)];
        const base = Number(odd.dataset.base);
        const swing = Number(odd.dataset.swing);
        const next = Math.max(1.1, base + (Math.random() * 2 - 1) * swing);
        odd.textContent = next.toFixed(2) + "x";
        if (!reduceMotion) {
            odd.classList.remove("is-hot");
            window.setTimeout(() => {
                odd.classList.add("is-hot");
            }, 20);
        }
    }, 1700);
}
