import { useState } from "react";
import {
  ArrowLeft,
  CheckCircle2,
  CircleX,
  Paperclip,
  RotateCcw,
  Send,
  UserPlus,
} from "lucide-react";

const initialThreads = [
  {
    id: 1,
    initials: "MP",
    citizen: "Maria Pacana",
    subject: "Road flooding near Barangay Sainz",
    preview: "The drainage has been blocked since yesterday afternoon.",
    time: "8 min",
    priority: "Urgent",
    status: "New",
    category: "Flooding",
    barangay: "Sainz",
    unread: true,
    assignee: "Unassigned",
    messages: [
      { author: "Maria Pacana", text: "The drainage canal in front of our house is completely blocked. Rainwater has started entering several homes.", time: "Today, 9:12 AM" },
    ],
  },
  {
    id: 2,
    initials: "JR",
    citizen: "Jose Reyes",
    subject: "Streetlight not working",
    preview: "There are two damaged poles along the public market.",
    time: "32 min",
    priority: "Standard",
    status: "In progress",
    category: "Street lighting",
    barangay: "Poblacion",
    unread: true,
    assignee: "Engr. Santos",
    messages: [
      { author: "Jose Reyes", text: "The streetlight near Gate 3 is still off. Two poles are leaning toward the road.", time: "Today, 8:46 AM" },
      { author: "You", text: "Thank you for reporting this. We have forwarded it to the electrical maintenance team.", time: "Today, 8:58 AM", admin: true },
    ],
  },
  {
    id: 3,
    initials: "AL",
    citizen: "Ana Lumaad",
    subject: "Request for damaged road inspection",
    preview: "Thank you. The crew completed the temporary repair.",
    time: "Yesterday",
    priority: "Standard",
    status: "Resolved",
    category: "Roads",
    barangay: "Central",
    unread: false,
    assignee: "Engr. Santos",
    messages: [
      { author: "Ana Lumaad", text: "The road beside the covered court has a large crack. Please inspect it when possible.", time: "Yesterday, 3:20 PM" },
      { author: "You", text: "Our crew completed the temporary repair and scheduled an inspection.", time: "Yesterday, 4:05 PM", admin: true },
    ],
  },
];

export default function InboxPage() {
  const [threads, setThreads] = useState(initialThreads);
  const [activeId, setActiveId] = useState(1);
  const [filter, setFilter] = useState("All");
  const [mobileOpen, setMobileOpen] = useState(false);
  const [reply, setReply] = useState("");
  const active = threads.find((thread) => thread.id === activeId) ?? threads[0];
  const visibleThreads = filter === "All" ? threads : threads.filter((thread) => thread.status === filter);

  function updateActive(updates) {
    setThreads((current) => current.map((thread) => (
      thread.id === activeId ? { ...thread, ...updates } : thread
    )));
  }

  function openThread(id) {
    setActiveId(id);
    setMobileOpen(true);
    setThreads((current) => current.map((thread) => (
      thread.id === id ? { ...thread, unread: false } : thread
    )));
  }

  function sendReply() {
    const text = reply.trim();
    if (!text) return;
    setThreads((current) => current.map((thread) => (
      thread.id === activeId ? {
        ...thread,
        status: thread.status === "New" ? "In progress" : thread.status,
        messages: [...thread.messages, { author: "You", text, time: "Just now", admin: true }],
      } : thread
    )));
    setReply("");
  }

  return (
    <section className={`admin-inbox${mobileOpen ? " mobile-thread-open" : ""}`}>
      <aside className="inbox-thread-list" id="inbox-thread-list" aria-label="Support threads">
        <div className="inbox-thread-list-head">
          <div>
            <p className="inbox-overline">Support inbox</p>
            <h2>Citizen conversations</h2>
          </div>
          <span className="inbox-unread-total">{threads.filter((thread) => thread.unread).length} unread</span>
        </div>

        <div className="inbox-tabs" role="tablist" aria-label="Inbox status">
          {["All", "New", "In progress", "Resolved"].map((status) => (
            <button key={status} type="button" role="tab" aria-selected={filter === status} className={`inbox-tab${filter === status ? " active" : ""}`} onClick={() => setFilter(status)}>
              {status}
            </button>
          ))}
        </div>

        <div className="inbox-thread-items">
          {visibleThreads.map((thread) => (
            <button key={thread.id} type="button" className={`inbox-thread-row${thread.id === activeId ? " active" : ""}${thread.unread ? " unread" : ""}`} onClick={() => openThread(thread.id)}>
              <span className="inbox-avatar">{thread.initials}</span>
              <span className="inbox-thread-copy">
                <span className="inbox-thread-name-line">
                  <strong>{thread.citizen}</strong>
                  {thread.unread && <i aria-label="Unread" />}
                </span>
                <b>{thread.subject}</b>
                <small>{thread.preview}</small>
              </span>
              <span className="inbox-thread-meta">
                <time>{thread.time}</time>
                <span className={`inbox-status ${thread.priority === "Urgent" ? "urgent" : ""}`}>{thread.priority}</span>
              </span>
            </button>
          ))}
        </div>
      </aside>

      <div className="inbox-conversation" id="inbox-conversation">
        <header className="inbox-conversation-head">
          <button className="inbox-back icon-button" type="button" onClick={() => setMobileOpen(false)} aria-label="Back to conversations">
            <ArrowLeft size={18} />
          </button>
          <div className="inbox-conversation-title">
            <p>{active.citizen}</p>
            <h2>{active.subject}</h2>
          </div>
          <span className={`inbox-thread-status ${active.status === "Resolved" ? "resolved" : ""}`}>
            {active.status}
          </span>
          <div className="inbox-actions">
            <button className="inbox-action" type="button" onClick={() => updateActive({ assignee: "You" })}>
              <UserPlus size={16} />
              <span>Assign</span>
            </button>
            {active.status === "Resolved" ? (
              <button className="inbox-action" type="button" onClick={() => updateActive({ status: "In progress" })}>
                <RotateCcw size={16} />
                <span>Reopen</span>
              </button>
            ) : (
              <button className="inbox-action primary" type="button" onClick={() => updateActive({ status: "Resolved" })}>
                <CheckCircle2 size={16} />
                <span>Mark resolved</span>
              </button>
            )}
            <button className="inbox-action" type="button" onClick={() => updateActive({ status: "Resolved" })}>
              <CircleX size={16} />
              <span>Close</span>
            </button>
          </div>
        </header>

        <div className="inbox-message-area">
          <div className="inbox-citizen-context">
            <div><span>Category</span><strong>{active.category}</strong></div>
            <div><span>Urgency</span><strong className={active.priority === "Urgent" ? "urgent-text" : ""}>{active.priority}</strong></div>
            <div><span>Barangay</span><strong>{active.barangay}</strong></div>
            <div><span>Subject</span><strong>{active.subject}</strong></div>
            <div><span>Assigned to</span><strong>{active.assignee}</strong></div>
          </div>

          <div className="inbox-message-date">Today</div>
          {active.messages.map((message, index) => (
            <div className={`inbox-message-row${message.admin ? " admin" : ""}`} key={`${message.time}-${index}`}>
              {!message.admin && <span className="inbox-avatar">{active.initials}</span>}
              <div className="inbox-message-bubble">
                <strong>{message.author}</strong>
                <p>{message.text}</p>
                <time>{message.time}</time>
              </div>
            </div>
          ))}
        </div>

        <div className="inbox-composer">
          <button type="button" className="icon-button inbox-attach" aria-label="Attach a file">
            <Paperclip size={18} />
          </button>
          <label className="sr-only" htmlFor="inbox-reply">Message</label>
          <textarea
            id="inbox-reply"
            value={reply}
            onChange={(event) => setReply(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault();
                sendReply();
              }
            }}
            placeholder="Message…"
            rows={1}
          />
          <button type="button" className="inbox-send" onClick={sendReply} disabled={!reply.trim()}>
            <Send size={17} />
            <span>Send</span>
          </button>
          <span className="inbox-composer-hint">Attach files or enter to send</span>
        </div>
      </div>
    </section>
  );
}
