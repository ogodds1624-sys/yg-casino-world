const STORE_KEY = "casino-world-backend";
const MEMBER_KEY = "casino-world-member";
const REF_KEY = "casino-world-ref";
const PARTNER_KEY = "casino-world-partner";

const readStore = () => {
    const empty = { members: [], transactions: [], partners: [], payouts: [], applications: [] };
    try {
        const saved = JSON.parse(localStorage.getItem(STORE_KEY));
        if (saved && Array.isArray(saved.members) && Array.isArray(saved.transactions) && Array.isArray(saved.partners)) {
            if (!Array.isArray(saved.payouts)) {
                saved.payouts = [];
            }
            if (!Array.isArray(saved.applications)) {
                saved.applications = [];
            }
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

const goTo = (url) => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) {
        window.location.href = url;
        return;
    }
    document.body.classList.add("is-leaving");
    window.setTimeout(() => {
        window.location.href = url;
    }, 180);
};

window.addEventListener("pageshow", () => {
    document.body.classList.remove("is-leaving");
});

const currentMember = (store) => {
    return store.members.find((member) => member.id === sessionStorage.getItem(MEMBER_KEY));
};

const packagePage = (country) => country === "ngn" ? "packageN.html" : "plist.html";

const isRegistered = (member) => Boolean(member && member.phone);

const hasCountry = (member) => Boolean(member && (member.country === "gh" || member.country === "ngn"));

const nextStep = (member) => {
    if (!hasCountry(member)) {
        return "country.html";
    }
    return isRegistered(member) ? packagePage(member.country) : "connecting.html?country=" + member.country;
};

const homeAccount = document.getElementById("home-account");
if (homeAccount && new URLSearchParams(window.location.search).get("account") === "test") {
    const store = readStore();
    let testMember = store.members.find((item) => item.email.toLowerCase() === "ama.mensah@example.com");
    if (!testMember) {
        testMember = {
            id: "test-ama",
            name: "Ama Mensah",
            email: "ama.mensah@example.com",
            joined: new Date().toISOString(),
            phone: "+233 24 123 4567",
            country: "gh",
            status: "UNPAID",
            referredBy: ""
        };
        store.members.unshift(testMember);
        writeStore(store);
    }
    sessionStorage.setItem(MEMBER_KEY, testMember.id);
    const clean = new URL(window.location.href);
    clean.searchParams.delete("account");
    window.history.replaceState(null, "", clean.pathname + clean.search + clean.hash);
}
if (homeAccount) {
    const member = currentMember(readStore());
    if (member) {
        const name = document.createElement("span");
        name.className = "header-name";
        name.textContent = member.name;
        name.title = member.name;
        const signOut = document.createElement("button");
        signOut.type = "button";
        signOut.className = "button";
        signOut.textContent = "Sign out";
        signOut.addEventListener("click", () => {
            sessionStorage.removeItem(MEMBER_KEY);
            goTo("index.html");
        });
        homeAccount.replaceChildren(name, signOut);
    }
}

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

const commissionPercent = (partner) => {
    const value = Number(partner && partner.commission);
    if (!Number.isFinite(value)) {
        return 0;
    }
    return Math.min(100, Math.max(0, value));
};

const formatAmount = (amount) => {
    const value = Math.round((Number(amount) + Number.EPSILON) * 100) / 100;
    return Number.isInteger(value) ? String(value) : value.toFixed(2);
};

const partnerEarnings = (gross, percent) => {
    const commission = gross * commissionPercent({ commission: percent }) / 100;
    return gross - commission;
};

const yesterdayKey = () => {
    const date = new Date();
    date.setDate(date.getDate() - 1);
    return dayKey(date);
};

const dayLabel = (key) => {
    const date = new Date(key + "T12:00:00");
    return date.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });
};

const currentPartner = (store) => {
    return store.partners.find((partner) => partner.id === sessionStorage.getItem(PARTNER_KEY));
};

const partnerDayEarnings = (store, partner, day) => {
    const referred = store.transactions.filter((item) => {
        return paymentReceived(item) && partner.referral && item.referral === partner.referral && (!day || dayKey(item.date) === day);
    });
    const ghs = referred.filter((item) => item.country !== "ngn").reduce((total, item) => total + packageAmount(item.package), 0);
    const ngn = referred.filter((item) => item.country === "ngn").reduce((total, item) => total + packageAmount(item.package), 0);
    return {
        ghs: partnerEarnings(ghs, partner.commission),
        ngn: partnerEarnings(ngn, partner.commission)
    };
};

const takenReferrals = (partners) => {
    const taken = new Set();
    partners.forEach((partner) => {
        if (partner.referral) {
            taken.add(partner.referral);
        }
    });
    return taken;
};

const referralCode = (name, taken) => {
    const letters = String(name || "").toUpperCase().replace(/[^A-Z]/g, "");
    const base = letters.slice(0, 4) || "PART";
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    do {
        let suffix = "";
        for (let i = 0; i < 4; i += 1) {
            suffix += alphabet[Math.floor(Math.random() * alphabet.length)];
        }
        code = base + suffix;
    } while (taken.has(code));
    taken.add(code);
    return code;
};

const ensureReferrals = (store) => {
    const taken = takenReferrals(store.partners);
    let changed = false;
    store.partners.forEach((partner) => {
        if (!partner.referral) {
            partner.referral = referralCode(partner.name, taken);
            changed = true;
        }
    });
    if (changed) {
        writeStore(store);
    }
};

const referralLink = (code) => {
    const url = new URL("index.html", window.location.href);
    url.search = "";
    url.hash = "";
    url.searchParams.set("ref", code);
    return url.href;
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

const paymentReceived = (item) => item.status === "PAID" || item.status === "RECEIVED";

const referrerOf = (store, code) => {
    if (!code) {
        return null;
    }
    return store.partners.find((partner) => partner.referral === code) || null;
};

const appendMemberRow = (body, member, store) => {
    const joined = member.joined ? new Date(member.joined) : null;
    const joinedOk = joined && !Number.isNaN(joined.getTime());
    const row = document.createElement("tr");
    const referrer = referrerOf(store, member.referredBy);
    const referredName = referrer ? referrer.name : (member.referredBy || "");
    row.dataset.search = [member.name, member.email, member.referredBy, referredName, member.status].join(" ").toLowerCase();
    const status = document.createElement("td");
    status.append(statusBadge(member.status));
    const referred = document.createElement("td");
    if (referredName) {
        referred.append(Object.assign(document.createElement("span"), { className: "referral-pill", textContent: referredName }));
    } else {
        referred.textContent = "—";
    }
    row.append(
        stackCell(member.name || "—", member.email || "", "member-name", "member-email"),
        joinedOk
            ? stackCell(joined.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }), joined.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }), "joined-date", "joined-time")
            : textCell("—"),
        status,
        referred
    );
    body.append(row);
};

const renderBackend = () => {
    if (!document.getElementById("panel-members")) {
        return;
    }
    const store = readStore();
    const paid = store.transactions.filter((item) => paymentReceived(item));
    const today = dayKey(new Date());
    const sumFor = (country, onlyToday) => {
        return paid
            .filter((item) => (item.country === "ngn" ? "ngn" : "gh") === country)
            .filter((item) => !onlyToday || dayKey(item.date) === today)
            .reduce((total, item) => total + packageAmount(item.package), 0);
    };
    const membersAmount = document.getElementById("stat-members");
    if (membersAmount) {
        membersAmount.textContent = String(store.members.length);
        document.getElementById("stat-members-note").textContent = store.members.length + " registered user" + (store.members.length === 1 ? "" : "s");
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
        appendMemberRow(memberBody, member, store);
    });
    document.getElementById("members-empty").hidden = store.members.length !== 0;

    const transactionBody = document.querySelector("#panel-transactions .members tbody");
    transactionBody.replaceChildren();
    store.transactions.forEach((item) => {
        const when = new Date(item.date);
        const row = document.createElement("tr");
        row.dataset.search = [item.name, item.email, item.package, item.proof].join(" ").toLowerCase();
        const proof = document.createElement("td");
        if (item.proofImage) {
            const shot = document.createElement("img");
            shot.className = "proof-shot";
            shot.src = item.proofImage;
            shot.alt = "Payment screenshot from " + (item.name || "member");
            shot.addEventListener("click", () => {
                const view = document.getElementById("proof-view");
                const image = document.getElementById("proof-view-image");
                if (!view || !image) {
                    return;
                }
                image.src = item.proofImage;
                view.hidden = false;
            });
            proof.append(shot);
        } else {
            proof.textContent = item.proof || "—";
        }
        const referral = document.createElement("td");
        if (item.referral) {
            referral.append(Object.assign(document.createElement("span"), { className: "referral-pill", textContent: item.referral }));
        } else {
            referral.textContent = "—";
        }
        const memberRecord = store.members.find((member) => member.email && item.email && member.email.toLowerCase() === item.email.toLowerCase());
        const memberName = item.name || (memberRecord ? memberRecord.name : "") || "—";
        const packageAmountLabel = item.package || "—";
        const market = item.country === "ngn" ? "Nigeria" : "Ghana";
        const status = document.createElement("td");
        const markPayment = (nextStatus) => {
            const next = readStore();
            const saved = next.transactions.find((entry) => entry.id === item.id);
            if (!saved || paymentReceived(saved) || saved.status === "REJECTED") {
                return;
            }
            saved.status = nextStatus;
            const member = next.members.find((entry) => entry.email && saved.email && entry.email.toLowerCase() === saved.email.toLowerCase());
            if (member && nextStatus === "RECEIVED") {
                member.status = "PAID";
            }
            writeStore(next);
            renderBackend();
        };
        if (paymentReceived(item)) {
            const badge = document.createElement("span");
            badge.className = "badge-paid";
            badge.textContent = "Received";
            status.append(badge);
        } else if (item.status === "REJECTED") {
            const badge = document.createElement("span");
            badge.className = "badge-unpaid";
            badge.textContent = "Rejected";
            status.append(badge);
        } else {
            const actions = document.createElement("div");
            actions.className = "application-actions";
            const received = document.createElement("button");
            received.type = "button";
            received.className = "copy";
            received.textContent = "Approve";
            const reject = document.createElement("button");
            reject.type = "button";
            reject.className = "copy is-delete";
            reject.textContent = "Reject";
            received.addEventListener("click", () => {
                markPayment("RECEIVED");
            });
            reject.addEventListener("click", () => {
                markPayment("REJECTED");
            });
            actions.append(received, reject);
            status.append(actions);
        }
        const whenOk = !Number.isNaN(when.getTime());
        row.append(
            whenOk
                ? stackCell(when.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }), when.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }), "joined-date", "joined-time")
                : textCell("—"),
            stackCell(memberName, item.email || "", "member-name", "member-email"),
            stackCell(packageAmountLabel, market, "member-name", "member-email"),
            proof,
            referral,
            status
        );
        transactionBody.append(row);
    });
    document.getElementById("transactions-empty").hidden = store.transactions.length !== 0;

    const partnerBody = document.getElementById("partner-body");
    ensureReferrals(store);
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
        const ghsCell = textCell("");
        const ngnCell = textCell("");
        const paintEarnings = (percent) => {
            ghsCell.textContent = "GHS " + formatAmount(partnerEarnings(ghs, percent));
            ngnCell.textContent = "NGN " + formatAmount(partnerEarnings(ngn, percent));
        };
        const commission = document.createElement("input");
        commission.type = "number";
        commission.min = "0";
        commission.max = "100";
        commission.step = "0.01";
        commission.className = "commission-input";
        commission.value = String(commissionPercent(partner));
        commission.setAttribute("aria-label", "Commission percent for " + partner.name);
        const saveCommission = document.createElement("button");
        saveCommission.type = "button";
        saveCommission.className = "copy";
        saveCommission.textContent = partner.commissionLocked ? "Saved" : "Save";
        const editCommission = document.createElement("button");
        editCommission.type = "button";
        editCommission.className = "copy";
        editCommission.textContent = "Edit";
        const lockCommission = (locked) => {
            commission.disabled = locked;
            saveCommission.disabled = locked;
            saveCommission.textContent = locked ? "Saved" : "Save";
            editCommission.hidden = !locked;
        };
        lockCommission(Boolean(partner.commissionLocked));
        editCommission.addEventListener("click", () => {
            lockCommission(false);
            commission.focus();
        });
        commission.addEventListener("input", () => {
            if (!commission.disabled) {
                paintEarnings(commission.value);
            }
        });
        saveCommission.addEventListener("click", () => {
            const percent = commissionPercent({ commission: commission.value });
            commission.value = String(percent);
            paintEarnings(percent);
            const next = readStore();
            const saved = next.partners.find((entry) => entry.id === partner.id) || next.partners.find((entry) => entry.email === partner.email);
            if (!saved) {
                return;
            }
            saved.commission = percent;
            saved.commissionLocked = true;
            writeStore(next);
            lockCommission(true);
        });
        const commissionCell = document.createElement("td");
        const commissionWrap = document.createElement("div");
        commissionWrap.className = "commission-lock";
        commissionWrap.append(commission, saveCommission, editCommission);
        commissionCell.append(commissionWrap);
        paintEarnings(partner.commission);
        const action = document.createElement("td");
        const remove = document.createElement("button");
        remove.type = "button";
        remove.className = "copy is-delete";
        remove.textContent = "Delete";
        remove.addEventListener("click", () => {
            const next = readStore();
            const index = next.partners.findIndex((entry) => entry.id ? entry.id === partner.id : entry.email === partner.email);
            if (index < 0) {
                return;
            }
            const removed = next.partners.splice(index, 1)[0];
            writeStore(next);
            if (sessionStorage.getItem(PARTNER_KEY) === removed.id) {
                sessionStorage.removeItem(PARTNER_KEY);
            }
            renderBackend();
        });
        action.append(remove);
        row.append(
            stackCell(partner.name, partner.email, "member-name", "member-email"),
            textCell("Active"),
            code,
            textCell(partner.referral ? referralLink(partner.referral) : "—"),
            commissionCell,
            ghsCell,
            ngnCell,
            action
        );
        partnerBody.append(row);
    });
    document.getElementById("partners-empty").hidden = store.partners.length !== 0;

    const applicationBody = document.getElementById("application-body");
    const applicationCard = document.getElementById("partner-applications");
    if (applicationBody) {
        const waiting = store.applications.filter((item) => item.status === "PENDING" || item.status === "REJECTED");
        if (applicationCard) {
            applicationCard.hidden = waiting.length === 0;
        }
        applicationBody.replaceChildren();
        waiting.forEach((item) => {
            const when = new Date(item.appliedAt);
            const row = document.createElement("tr");
            row.dataset.keep = "yes";
            const action = document.createElement("td");
            if (item.status === "PENDING") {
                const actions = document.createElement("div");
                actions.className = "application-actions";
                const approve = document.createElement("button");
                approve.type = "button";
                approve.className = "copy";
                approve.textContent = "Approve";
                const reject = document.createElement("button");
                reject.type = "button";
                reject.className = "copy is-delete";
                reject.textContent = "Reject";
                const decide = (status) => {
                    const next = readStore();
                    const saved = next.applications.find((entry) => entry.id === item.id);
                    if (!saved || saved.status !== "PENDING") {
                        return;
                    }
                    if (status === "APPROVED") {
                        if (!next.partners.some((partner) => partner.email.toLowerCase() === saved.email.toLowerCase())) {
                            next.partners.unshift({
                                id: saved.id,
                                name: saved.name,
                                email: saved.email,
                                password: saved.password,
                                referral: referralCode(saved.name, takenReferrals(next.partners)),
                                commission: 0
                            });
                        }
                        next.applications = next.applications.filter((entry) => entry.id !== saved.id);
                    } else {
                        saved.status = status;
                    }
                    writeStore(next);
                    renderBackend();
                };
                approve.addEventListener("click", () => {
                    decide("APPROVED");
                });
                reject.addEventListener("click", () => {
                    decide("REJECTED");
                });
                actions.append(approve, reject);
                action.append(actions);
            } else {
                action.textContent = "—";
            }
            const statusText = item.status === "APPROVED" ? "Approved" : item.status === "REJECTED" ? "Rejected" : "Pending";
            row.append(
                stackCell(when.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }), when.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }), "joined-date", "joined-time"),
                stackCell(item.name, item.email, "member-name", "member-email"),
                textCell(item.name + " wants to become a partner."),
                textCell(statusText),
                action
            );
            applicationBody.append(row);
        });
        document.getElementById("applications-empty").hidden = waiting.length !== 0;
    }

    const payoutBody = document.getElementById("payout-request-body");
    if (payoutBody) {
        payoutBody.replaceChildren();
        store.payouts.forEach((item) => {
            const when = new Date(item.requestedAt);
            const row = document.createElement("tr");
            row.dataset.keep = "yes";
            row.append(
                stackCell(when.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }), when.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }), "joined-date", "joined-time"),
                stackCell(item.partnerName || "—", item.partnerEmail || "", "member-name", "member-email"),
                textCell(dayLabel(item.day)),
                textCell("GHS " + formatAmount(item.ghs)),
                textCell("NGN " + formatAmount(item.ngn)),
                textCell("Requested")
            );
            payoutBody.append(row);
        });
        document.getElementById("payouts-empty").hidden = store.payouts.length !== 0;
    }
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
        partners: document.getElementById("panel-partners"),
        payouts: document.getElementById("panel-payouts")
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
        if (row.dataset.keep === "yes") {
            return;
        }
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
        let referral = String(data.get("referral")).trim();
        const commission = commissionPercent({ commission: data.get("commission") });
        if (!password) {
            return;
        }
        const store = readStore();
        const taken = takenReferrals(store.partners);
        if (!referral || taken.has(referral)) {
            referral = referralCode(name, taken);
        }
        store.partners.unshift({
            id: Date.now().toString(36),
            name,
            email,
            password,
            referral,
            commission
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
        const data = new FormData(partnerSignIn);
        const email = String(data.get("email")).trim().toLowerCase();
        const password = String(data.get("password"));
        const store = readStore();
        const partner = store.partners.find((item) => item.email.toLowerCase() === email);
        const error = document.getElementById("partner-sign-in-error");
        const application = store.applications.find((item) => item.email.toLowerCase() === email);
        if (!partner || (partner.password && partner.password !== password)) {
            if (error) {
                if (!partner && application && application.status === "PENDING") {
                    error.textContent = "Your application is waiting for admin approval.";
                } else if (!partner && application && application.status === "REJECTED") {
                    error.textContent = "Your application was rejected.";
                } else {
                    error.textContent = "That email or password is not correct.";
                }
                error.hidden = false;
            }
            return;
        }
        if (!partner.password) {
            partner.password = password;
            writeStore(store);
        }
        if (error) {
            error.hidden = true;
        }
        sessionStorage.setItem(PARTNER_KEY, partner.id);
        goTo("partner.html");
    });
    partnerJoin.addEventListener("submit", (event) => {
        event.preventDefault();
        const data = new FormData(partnerJoin);
        const name = String(data.get("name")).trim();
        const email = String(data.get("email")).trim();
        const password = String(data.get("password"));
        const note = document.getElementById("partner-join-note");
        const showNote = (message, isError) => {
            if (!note) {
                return;
            }
            note.textContent = message;
            note.classList.toggle("is-error", isError);
            note.hidden = false;
        };
        if (!name || !email || password.length < 6) {
            showNote("Enter your full name, email, and a password of at least 6 characters.", true);
            return;
        }
        const store = readStore();
        if (store.partners.some((item) => item.email.toLowerCase() === email.toLowerCase())) {
            showNote("This email is already a partner. Sign in instead.", true);
            return;
        }
        const existing = store.applications.find((item) => item.email.toLowerCase() === email.toLowerCase());
        const waitPopup = document.getElementById("partner-wait-popup");
        const showWait = () => {
            if (!waitPopup) {
                return;
            }
            waitPopup.hidden = false;
            const close = document.getElementById("partner-wait-close");
            if (close) {
                close.focus();
            }
        };
        if (existing && existing.status === "PENDING") {
            showNote("Your application is already with the admin.", true);
            showWait();
            return;
        }
        if (existing) {
            existing.name = name;
            existing.email = email;
            existing.password = password;
            existing.status = "PENDING";
            existing.appliedAt = new Date().toISOString();
        } else {
            store.applications.unshift({
                id: Date.now().toString(36),
                name,
                email,
                password,
                status: "PENDING",
                appliedAt: new Date().toISOString()
            });
        }
        writeStore(store);
        partnerJoin.reset();
        showNote("Your application was sent to the admin.", false);
        showWait();
    });
    const waitPopup = document.getElementById("partner-wait-popup");
    const closeWait = document.getElementById("partner-wait-close");
    if (waitPopup && closeWait) {
        closeWait.addEventListener("click", () => {
            waitPopup.hidden = true;
        });
        waitPopup.addEventListener("click", (event) => {
            if (event.target === waitPopup) {
                waitPopup.hidden = true;
            }
        });
        document.addEventListener("keydown", (event) => {
            if (event.key === "Escape" && !waitPopup.hidden) {
                waitPopup.hidden = true;
            }
        });
    }

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
        referrals: document.getElementById("partner-panel-referrals"),
        payout: document.getElementById("partner-panel-payout")
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
    const renderPartnerReferrals = () => {
        const referralBody = document.querySelector("#partner-panel-referrals .members tbody");
        if (!referralBody) {
            return;
        }
        const store = readStore();
        const partner = currentPartner(store);
        const people = store.members.filter((member) => partner && member.referredBy && member.referredBy === partner.referral);
        referralBody.replaceChildren();
        people.forEach((member) => {
            appendMemberRow(referralBody, member, store);
        });
        const referralsEmpty = document.getElementById("referrals-empty");
        if (referralsEmpty) {
            referralsEmpty.hidden = people.length !== 0;
        }
    };
    const partnerNet = (store, partner, country, day) => {
        if (!partner) {
            return 0;
        }
        const gross = store.transactions
            .filter((item) => paymentReceived(item) && item.referral === partner.referral && (item.country === "ngn" ? "ngn" : "gh") === country && (!day || dayKey(item.date) === day))
            .reduce((total, item) => total + packageAmount(item.package), 0);
        return partnerEarnings(gross, partner.commission);
    };
    const renderPartnerOverview = () => {
        const dailyGh = document.getElementById("partner-daily-gh");
        if (!dailyGh) {
            return;
        }
        const store = readStore();
        const partner = currentPartner(store);
        const today = dayKey(new Date());
        dailyGh.textContent = "GHS " + formatAmount(partnerNet(store, partner, "gh", today));
        document.getElementById("partner-total-gh").textContent = "GHS " + formatAmount(partnerNet(store, partner, "gh"));
        document.getElementById("partner-daily-ng").textContent = "₦" + formatAmount(partnerNet(store, partner, "ngn", today));
        document.getElementById("partner-total-ng").textContent = "₦" + formatAmount(partnerNet(store, partner, "ngn"));
        document.querySelectorAll("[data-partner-revenue]").forEach((table) => {
            const country = table.dataset.partnerRevenue;
            table.replaceChildren();
            for (let offset = 6; offset >= 0; offset -= 1) {
                const date = new Date();
                date.setDate(date.getDate() - offset);
                const key = dayKey(date);
                const row = document.createElement("div");
                row.className = key === today ? "row active" : "row";
                const label = document.createElement("span");
                label.textContent = date.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });
                const value = document.createElement("span");
                value.textContent = (country === "ngn" ? "NGN " : "GHS ") + formatAmount(partnerNet(store, partner, country, key));
                row.append(label, value);
                table.append(row);
            }
        });
        const paymentBody = document.getElementById("partner-payment-body");
        if (!paymentBody) {
            return;
        }
        paymentBody.replaceChildren();
        const payments = partner ? store.transactions.filter((item) => item.referral === partner.referral) : [];
        payments.forEach((item) => {
            const when = new Date(item.date);
            const row = document.createElement("tr");
            const received = paymentReceived(item);
            const yourAmount = received ? (item.country === "ngn" ? "₦" : "GHS ") + formatAmount(partnerEarnings(packageAmount(item.package), partner.commission)) : "—";
            const statusText = received ? "Received" : item.status === "REJECTED" ? "Rejected" : "Waiting";
            row.append(
                !Number.isNaN(when.getTime())
                    ? stackCell(when.toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }), when.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }), "joined-date", "joined-time")
                    : textCell("—"),
                textCell(item.name || "—"),
                textCell(item.package || "—"),
                textCell(yourAmount),
                textCell(statusText)
            );
            paymentBody.append(row);
        });
        const paymentsEmpty = document.getElementById("partner-payments-empty");
        if (paymentsEmpty) {
            paymentsEmpty.hidden = payments.length !== 0;
        }
    };
    renderPartnerReferrals();
    renderPartnerOverview();
    window.addEventListener("storage", (event) => {
        if (event.key === STORE_KEY) {
            renderPartnerReferrals();
            renderPartnerOverview();
            renderPartnerPayout();
        }
    });
    const dashStart = window.location.hash.replace("#", "");
    if (dashPanels[dashStart]) {
        openDash(dashStart);
    }
    const codeNode = document.getElementById("referral-code");
    const linkNode = document.getElementById("referral-link");
    const copyReferral = document.getElementById("copy-referral");
    if (codeNode && linkNode && copyReferral) {
        const store = readStore();
        const partner = currentPartner(store);
        if (!partner) {
            copyReferral.hidden = true;
        } else {
            ensureReferrals(store);
            const link = referralLink(partner.referral);
            codeNode.textContent = partner.referral;
            linkNode.textContent = link;
            copyReferral.hidden = false;
            copyReferral.addEventListener("click", () => {
                const done = () => {
                    copyReferral.textContent = "Copied";
                    window.setTimeout(() => {
                        copyReferral.textContent = "Copy link";
                    }, 1500);
                };
                const fallback = () => {
                    const area = document.createElement("textarea");
                    area.value = link;
                    area.setAttribute("readonly", "");
                    area.style.position = "fixed";
                    area.style.left = "-9999px";
                    document.body.appendChild(area);
                    area.select();
                    document.execCommand("copy");
                    area.remove();
                    done();
                };
                if (navigator.clipboard && window.isSecureContext) {
                    navigator.clipboard.writeText(link).then(done).catch(fallback);
                    return;
                }
                fallback();
            });
        }
    }
}

const renderPartnerPayout = () => {
    const request = document.getElementById("payout-request");
    const ghsNode = document.getElementById("payout-ghs");
    const ngnNode = document.getElementById("payout-ngn");
    if (!request || !ghsNode || !ngnNode) {
        return;
    }
    const dayNode = document.getElementById("payout-day");
    const note = document.getElementById("payout-note");
    const signedOut = document.getElementById("payout-signed-out");
    const amounts = document.getElementById("payout-amounts");
    const store = readStore();
    const partner = currentPartner(store);
    const day = yesterdayKey();
    dayNode.textContent = dayLabel(day);
    if (!partner) {
        signedOut.hidden = false;
        amounts.hidden = true;
        request.hidden = true;
        note.textContent = "";
        return;
    }
    signedOut.hidden = true;
    amounts.hidden = false;
    request.hidden = false;
    const existing = store.payouts.find((item) => item.partnerId === partner.id && item.day === day);
    const earned = existing || partnerDayEarnings(store, partner, day);
    ghsNode.textContent = "GHS " + formatAmount(earned.ghs);
    ngnNode.textContent = "NGN " + formatAmount(earned.ngn);
    if (existing) {
        request.disabled = true;
        request.textContent = "Requested";
        note.textContent = "This payout is with the admin.";
        return;
    }
    const empty = earned.ghs <= 0 && earned.ngn <= 0;
    request.disabled = empty;
    request.textContent = "Request payout";
    note.textContent = empty ? "No earnings for yesterday." : "This is yesterday's earnings after commission.";
};

const payoutRequest = document.getElementById("payout-request");
if (payoutRequest) {
    payoutRequest.addEventListener("click", () => {
        const store = readStore();
        const partner = currentPartner(store);
        if (!partner) {
            return;
        }
        const day = yesterdayKey();
        if (store.payouts.some((item) => item.partnerId === partner.id && item.day === day)) {
            renderPartnerPayout();
            return;
        }
        const earned = partnerDayEarnings(store, partner, day);
        if (earned.ghs <= 0 && earned.ngn <= 0) {
            renderPartnerPayout();
            return;
        }
        store.payouts.unshift({
            id: Date.now().toString(36),
            partnerId: partner.id,
            partnerName: partner.name,
            partnerEmail: partner.email,
            day,
            ghs: earned.ghs,
            ngn: earned.ngn,
            status: "REQUESTED",
            requestedAt: new Date().toISOString()
        });
        writeStore(store);
        renderPartnerPayout();
    });
    renderPartnerPayout();
}

const proofView = document.getElementById("proof-view");
const proofClose = document.getElementById("proof-close");
if (proofView && proofClose) {
    proofClose.addEventListener("click", () => {
        proofView.hidden = true;
    });
    proofView.addEventListener("click", (event) => {
        if (event.target === proofView) {
            proofView.hidden = true;
        }
    });
}

const partnerSignOut = document.getElementById("partner-sign-out");
if (partnerSignOut) {
    partnerSignOut.addEventListener("click", (event) => {
        event.preventDefault();
        sessionStorage.removeItem(PARTNER_KEY);
        goTo("partnerlogs.html");
    });
}

const referralSearch = document.getElementById("referral-search");
if (referralSearch) {
    const referralsEmpty = document.getElementById("referrals-empty");
    referralSearch.addEventListener("input", () => {
        const query = referralSearch.value.trim().toLowerCase();
        const rows = document.querySelectorAll("#partner-panel-referrals .members tbody tr");
        let shown = 0;
        rows.forEach((row) => {
            const match = (row.dataset.search || "").includes(query);
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
        goTo(member ? nextStep(member) : "country.html");
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
            if (!member.referredBy && sessionStorage.getItem(REF_KEY)) {
                member.referredBy = sessionStorage.getItem(REF_KEY);
            }
            if (!member.joined) {
                member.joined = new Date().toISOString();
            }
            if (!member.status) {
                member.status = "UNPAID";
            }
        }
        writeStore(store);
        sessionStorage.setItem(MEMBER_KEY, member.id);
        goTo(nextStep(member));
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

const PRICE_KEY = "casino-world-prices";
const defaultPrices = {
    gh: [355, 455, 555],
    ngn: [42472.2, 54436.2, 66400.2],
    mins: [3, 5, 7]
};

const readPrices = () => {
    const fallback = {
        gh: defaultPrices.gh.slice(),
        ngn: defaultPrices.ngn.slice(),
        mins: defaultPrices.mins.slice()
    };
    try {
        const saved = JSON.parse(localStorage.getItem(PRICE_KEY));
        if (saved && Array.isArray(saved.gh) && saved.gh.length === 3 && Array.isArray(saved.ngn) && saved.ngn.length === 3) {
            return {
                gh: saved.gh.map(Number),
                ngn: saved.ngn.map(Number),
                mins: Array.isArray(saved.mins) && saved.mins.length === 3 ? saved.mins.map(Number) : fallback.mins
            };
        }
    } catch (error) {
        return fallback;
    }
    return fallback;
};

const sessionLabel = (minutes) => {
    const value = Number(minutes);
    return value + " min" + (value === 1 ? "" : "s") + " per session";
};

const formatPrice = (amount, country) => {
    const value = Number(amount);
    if (country === "ngn") {
        return "₦" + value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
    const digits = Number.isInteger(value) ? 0 : 2;
    return "GHS " + value.toLocaleString("en-US", { minimumFractionDigits: digits, maximumFractionDigits: digits });
};

const applyPrices = () => {
    const nodes = document.querySelectorAll("[data-package]");
    if (!nodes.length) {
        return;
    }
    const prices = readPrices();
    const ngnPage = document.body.dataset.market === "ngn" || new URLSearchParams(window.location.search).get("pay") === "ngn";
    const country = ngnPage ? "ngn" : "gh";
    nodes.forEach((node) => {
        const index = Number(node.dataset.package) - 1;
        if (!prices[country][index] && prices[country][index] !== 0) {
            return;
        }
        const label = formatPrice(prices[country][index], country);
        const price = node.querySelector(".price");
        if (price) {
            price.textContent = label;
        }
        const link = node.querySelector("a.button");
        if (link) {
            link.textContent = "Get " + label;
        }
        const amount = node.querySelector(".amount");
        if (amount) {
            amount.textContent = label;
        }
        const desc = node.querySelector(".desc");
        if (desc && prices.mins[index]) {
            desc.textContent = sessionLabel(prices.mins[index]);
        }
        node.querySelectorAll(".green").forEach((green) => {
            if (/GHS|₦/.test(green.textContent)) {
                green.textContent = label;
            }
        });
    });
};

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
            networkValue.textContent = bank.bank;
        }
        numberNode.textContent = bank.account;
        if (nameValue) {
            nameValue.textContent = bank.name;
        }
        if (payNetwork) {
            payNetwork.textContent = bank.bank || "bank";
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
    const momo = savedGateways ? savedGateways.momo : { network: "", number: "", name: "" };
    if (networkValue) {
        networkValue.textContent = momo.network;
    }
    numberNode.textContent = momo.number;
    if (nameValue) {
        nameValue.textContent = momo.name;
    }
    if (payNetwork) {
        payNetwork.textContent = momo.network || "MoMo";
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
        const close = document.querySelector(".momo-top a");
        if (close) {
            close.href = "packageN.html";
        }
        paymentForm.action = "packageN.html";
    }
    applyPrices();
    const statusNote = document.createElement("p");
    statusNote.id = "payment-status";
    statusNote.hidden = true;
    paymentForm.before(statusNote);
    const selectedAmount = () => document.querySelector(".amount").textContent.trim();
    const payCountry = () => new URLSearchParams(window.location.search).get("pay") === "ngn" ? "ngn" : "gh";

    const readScreenshot = (file) => new Promise((resolve) => {
        if (!file) {
            resolve("");
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            const image = new Image();
            image.onload = () => {
                const max = 640;
                const scale = Math.min(1, max / Math.max(image.width, image.height));
                const canvas = document.createElement("canvas");
                canvas.width = Math.max(1, Math.round(image.width * scale));
                canvas.height = Math.max(1, Math.round(image.height * scale));
                canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height);
                resolve(canvas.toDataURL("image/jpeg", 0.6));
            };
            image.onerror = () => resolve("");
            image.src = reader.result;
        };
        reader.onerror = () => resolve("");
        reader.readAsDataURL(file);
    });

    const matchingPayment = () => {
        const store = readStore();
        const member = currentMember(store);
        const email = member ? member.email.toLowerCase() : "";
        const amount = selectedAmount();
        const country = payCountry();
        return store.transactions.find((item) => item.package === amount && item.country === country && item.email.toLowerCase() === email && item.status !== "REJECTED");
    };

    const showPaymentState = () => {
        const saved = matchingPayment();
        if (!saved) {
            paymentForm.hidden = false;
            const store = readStore();
            const member = currentMember(store);
            const email = member ? member.email.toLowerCase() : "";
            const rejected = store.transactions.find((item) => item.package === selectedAmount() && item.country === payCountry() && item.email.toLowerCase() === email && item.status === "REJECTED");
            if (rejected) {
                statusNote.hidden = false;
                statusNote.textContent = "Payment rejected. Submit a new screenshot.";
            }
            return;
        }
        paymentForm.hidden = true;
        statusNote.hidden = false;
        statusNote.textContent = paymentReceived(saved) ? "Payment received." : "Waiting for admin confirmation.";
    };

    paymentForm.addEventListener("submit", (event) => {
        event.preventDefault();
        const proofFile = receipt && receipt.files ? receipt.files[0] : null;
        readScreenshot(proofFile).then((proofImage) => {
            const store = readStore();
            const member = currentMember(store);
            const record = {
                id: Date.now().toString(36),
                date: new Date().toISOString(),
                name: member ? member.name : "",
                email: member ? member.email : "",
                package: selectedAmount(),
                proof: proofFile ? proofFile.name : "",
                proofImage,
                referral: member ? member.referredBy : (sessionStorage.getItem(REF_KEY) || ""),
                status: "PENDING",
                country: payCountry()
            };
            store.transactions.unshift(record);
            try {
                writeStore(store);
            } catch (error) {
                store.transactions.shift();
                statusNote.hidden = false;
                statusNote.textContent = "That screenshot is too large. Choose a smaller image.";
                return;
            }
            showPaymentState();
        });
    });
    window.addEventListener("storage", (event) => {
        if (event.key === PRICE_KEY) {
            applyPrices();
        }
        showPaymentState();
    });
    showPaymentState();
}

if (!paymentForm) {
    applyPrices();
    window.addEventListener("storage", (event) => {
        if (event.key === PRICE_KEY) {
            applyPrices();
        }
    });
}

const connectForm = document.getElementById("connect-form");
if (connectForm) {
    const countries = {
        ngn: { dial: "+234", placeholder: "801 234 5678", flag: "flag-ngn" },
        gh: { dial: "+233", placeholder: "24 123 4567", flag: "flag-gh" }
    };
    const chosen = new URLSearchParams(window.location.search).get("country");
    const store = readStore();
    const member = currentMember(store);
    const country = hasCountry(member) ? member.country : (countries[chosen] ? chosen : "ngn");
    if (isRegistered(member)) {
        const card = connectForm.closest(".connect-card");
        if (card) {
            card.hidden = true;
        }
        goTo(packagePage(country));
    } else {
        const details = countries[country];
        document.getElementById("country").value = country;
        document.getElementById("dial-label").textContent = details.dial;
        document.getElementById("phone").placeholder = details.placeholder;
        document.getElementById("flag-ngn").hidden = details.flag !== "flag-ngn";
        document.getElementById("flag-gh").hidden = details.flag !== "flag-gh";
        connectForm.action = packagePage(country);

        connectForm.addEventListener("submit", (event) => {
            event.preventDefault();
            const nextStore = readStore();
            const nextMember = currentMember(nextStore);
            if (nextMember) {
                nextMember.country = country;
                nextMember.phone = details.dial + " " + String(new FormData(connectForm).get("phone")).trim();
                writeStore(nextStore);
            }
            goTo(connectForm.action);
        });
    }
}

const countryForm = document.querySelector('form[action="connecting.html"]');
if (countryForm) {
    const store = readStore();
    const member = currentMember(store);
    if (hasCountry(member)) {
        const card = countryForm.closest(".country-pick");
        if (card) {
            card.hidden = true;
        }
        goTo(nextStep(member));
    } else {
        countryForm.addEventListener("submit", (event) => {
            const chosenCountry = event.submitter ? event.submitter.value : "";
            const nextStore = readStore();
            const nextMember = currentMember(nextStore);
            if (nextMember && !nextMember.country && (chosenCountry === "gh" || chosenCountry === "ngn")) {
                nextMember.country = chosenCountry;
                writeStore(nextStore);
            }
        });
    }
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
            const prices = readPrices();
            ["gh", "ngn"].forEach((country) => {
                prices[country] = prices[country].map((current, index) => {
                    const input = document.getElementById("price-" + country + "-" + (index + 1));
                    const value = input ? Number(String(input.value).replace(/,/g, "")) : current;
                    return Number.isFinite(value) && value > 0 ? Math.round(value * 100) / 100 : current;
                });
            });
            prices.mins = (prices.mins || defaultPrices.mins.slice()).map((current, index) => {
                const input = document.getElementById("time-" + (index + 1));
                const value = input ? Number(String(input.value).replace(/,/g, "")) : current;
                return Number.isFinite(value) && value > 0 ? Math.round(value) : current;
            });
            localStorage.setItem(PRICE_KEY, JSON.stringify(prices));
            const note = document.getElementById("gateway-saved");
            note.hidden = false;
        });
        const savedPrices = readPrices();
        ["gh", "ngn"].forEach((country) => {
            savedPrices[country].forEach((amount, index) => {
                const input = document.getElementById("price-" + country + "-" + (index + 1));
                if (input) {
                    input.value = String(amount);
                }
            });
        });
        savedPrices.mins.forEach((minutes, index) => {
            const input = document.getElementById("time-" + (index + 1));
            if (input) {
                input.value = String(minutes);
            }
        });
    }
}

const aviatorOdd = document.getElementById("aviator-odd");
const aviatorPlane = document.querySelector(".aviator-plane");
const aviatorTrail = document.querySelector(".aviator-trail");
const aviatorClip = document.querySelector(".aviator-clip");
const aviatorHistory = document.getElementById("aviator-history");
if (aviatorOdd && aviatorPlane && aviatorTrail && aviatorClip) {
    const maxOdd = 5.99;
    const reduceFlight = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const trailLength = aviatorTrail.getTotalLength();
    aviatorTrail.style.strokeDasharray = String(trailLength);
    const tone = (value) => value < 2 ? "is-low" : value < 4 ? "is-mid" : "is-high";
    const paintHistory = () => {
        if (!aviatorHistory) {
            return;
        }
        aviatorHistory.querySelectorAll("li").forEach((item) => {
            const value = Number.parseFloat(item.textContent);
            item.className = tone(value);
        });
    };
    const remember = (value) => {
        if (!aviatorHistory) {
            return;
        }
        const item = document.createElement("li");
        item.textContent = value.toFixed(2) + "x";
        aviatorHistory.prepend(item);
        while (aviatorHistory.children.length > 6) {
            aviatorHistory.lastElementChild.remove();
        }
        paintHistory();
    };
    const paintTrail = (along) => {
        const clamped = Math.max(0, Math.min(1, along));
        aviatorTrail.style.strokeDashoffset = String(trailLength * (1 - clamped));
        const tip = aviatorTrail.getPointAtLength(trailLength * clamped);
        aviatorClip.setAttribute("width", String(Math.max(0, tip.x)));
    };
    const placePlane = (distance) => {
        const clamped = Math.max(0, Math.min(trailLength, distance));
        const point = aviatorTrail.getPointAtLength(clamped);
        const ahead = aviatorTrail.getPointAtLength(Math.min(trailLength, clamped + 12));
        const dx = ahead.x - point.x || 1;
        const dy = ahead.y - point.y;
        const span = Math.hypot(dx, dy) || 1;
        const extra = Math.max(0, distance - trailLength);
        const x = point.x + (dx / span) * extra + (dy / span) * 12;
        const y = point.y + (dy / span) * extra - (dx / span) * 12;
        const angle = Math.atan2(dy, dx) * 180 / Math.PI;
        aviatorPlane.setAttribute("transform", "translate(" + x + " " + y + ") rotate(" + angle + ") scale(2.7)");
    };
    const nextCrash = () => Math.round((1 + Math.random() * (maxOdd - 1)) * 100) / 100;
    const money = (amount) => amount.toFixed(2) + " GHS";
    const paintPanel = (panelState, label, payout, button) => {
        const won = panelState.cashed;
        const live = panelState.flying && !won;
        button.classList.toggle("is-live", live);
        button.classList.toggle("is-won", won);
        if (won) {
            label.textContent = "Won";
            payout.textContent = money(panelState.won);
            return;
        }
        if (!panelState.flying) {
            label.textContent = "Bet";
            payout.textContent = money(panelState.stake);
            return;
        }
        label.textContent = "Cash Out";
        payout.textContent = money(panelState.locked * panelState.odd);
    };
    let round = 0;
    const betPanels = [...document.querySelectorAll(".aviator-bet")].map((panel) => {
        const stakeNode = panel.querySelector(".aviator-amount strong");
        const button = panel.querySelector(".aviator-go");
        const label = button.querySelector("span");
        const payout = button.querySelector("strong");
        const panelState = {
            stake: 1,
            locked: 1,
            cashed: false,
            won: 0,
            round: -1,
            odd: 1,
            flying: false
        };
        const paintStake = () => {
            stakeNode.textContent = panelState.stake.toFixed(2);
        };
        const setStake = (next) => {
            panelState.stake = Math.min(500, Math.max(1, Math.round(next)));
            paintStake();
            if (!panelState.flying && !panelState.cashed) {
                payout.textContent = money(panelState.stake);
            }
        };
        panel.querySelectorAll(".aviator-step").forEach((step) => {
            step.addEventListener("click", () => {
                setStake(panelState.stake + Number(step.dataset.step));
            });
        });
        panel.querySelectorAll(".aviator-chip").forEach((chip) => {
            chip.addEventListener("click", () => {
                setStake(Number(chip.textContent));
            });
        });
        button.addEventListener("click", () => {
            if (!panelState.flying || panelState.cashed) {
                return;
            }
            panelState.cashed = true;
            panelState.won = Math.round(panelState.locked * panelState.odd * 100) / 100;
            paintPanel(panelState, label, payout, button);
        });
        return { panelState, label, payout, button };
    });
    const syncBets = (odd, flying) => {
        betPanels.forEach(({ panelState, label, payout, button }) => {
            if (panelState.round !== round) {
                panelState.round = round;
                panelState.locked = panelState.stake;
                panelState.cashed = false;
                panelState.won = 0;
            }
            panelState.odd = odd;
            panelState.flying = flying;
            paintPanel(panelState, label, payout, button);
        });
    };
    paintHistory();
    if (reduceFlight) {
        aviatorOdd.textContent = "2.40x";
        placePlane(trailLength * ((2.4 - 1) / (maxOdd - 1)));
        aviatorPlane.style.opacity = "1";
        paintTrail((2.4 - 1) / (maxOdd - 1));
        syncBets(2.4, true);
    } else {
        let cycleStart = performance.now();
        let crashOdd = nextCrash();
        let remembered = false;
        const fly = (now) => {
            const cycle = 2600 + ((crashOdd - 1) / (maxOdd - 1)) * 2800;
            let progress = (now - cycleStart) / cycle;
            if (progress >= 1) {
                cycleStart = now;
                crashOdd = nextCrash();
                remembered = false;
                progress = 0;
                round += 1;
            }
            const flying = progress < 0.84;
            const climb = flying ? progress / 0.84 : 1;
            const value = Math.min(maxOdd, 1 + (crashOdd - 1) * climb);
            const along = (value - 1) / (maxOdd - 1);
            if (!flying && !remembered) {
                remember(crashOdd);
                remembered = true;
            }
            aviatorOdd.textContent = value.toFixed(2) + "x";
            aviatorOdd.classList.toggle("is-crash", !flying);
            syncBets(value, flying);
            placePlane(trailLength * (flying ? along : along + ((progress - 0.84) / 0.16) * 0.08));
            aviatorPlane.style.opacity = flying ? "1" : String(Math.max(0, 1 - (progress - 0.84) / 0.16));
            paintTrail(along);
            window.requestAnimationFrame(fly);
        };
        window.requestAnimationFrame(fly);
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

document.addEventListener("click", (event) => {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.defaultPrevented) {
        return;
    }
    const link = event.target.closest("a[href]");
    if (!link || (link.target && link.target !== "_self") || link.hasAttribute("download")) {
        return;
    }
    const href = link.getAttribute("href");
    if (!href || href.startsWith("#") || href.startsWith("mailto:") || href.startsWith("tel:")) {
        return;
    }
    let next;
    try {
        next = new URL(link.href);
    } catch (error) {
        return;
    }
    if (next.origin !== window.location.origin) {
        return;
    }
    if (next.pathname === window.location.pathname && next.search === window.location.search) {
        return;
    }
    event.preventDefault();
    goTo(next.href);
});

document.addEventListener("submit", (event) => {
    const form = event.target;
    if (!(form instanceof HTMLFormElement) || event.defaultPrevented || (form.target && form.target !== "_self")) {
        return;
    }
    const action = form.getAttribute("action") || window.location.href;
    if (action.startsWith("#")) {
        return;
    }
    let next;
    try {
        next = new URL(action, window.location.href);
    } catch (error) {
        return;
    }
    if (next.origin !== window.location.origin) {
        return;
    }
    if ((form.method || "get").toLowerCase() === "get") {
        const data = new FormData(form, event.submitter);
        next.search = new URLSearchParams(data).toString();
    }
    event.preventDefault();
    goTo(next.href);
});
