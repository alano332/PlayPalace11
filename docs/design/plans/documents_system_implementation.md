# Documents System Implementation Progress

## Completed (Session 1)

### Database Layer (prior session)
- `fluent_languages` column on `users` table (JSON text)
- `transcriber_assignments` table with full CRUD methods
- Migration support in `server/persistence/database.py`

### Backend Infrastructure
- **NetworkUser.fluent_languages**: property, setter, plumbed from DB on login/reconnect (`server/core/users/network_user.py`, `server/core/server.py`)
- **Fluent languages option**: toggle menu in options, uses `show_language_menu` with on/off status labels, saves to DB (`server/core/server.py`, `server/locales/en/main.ftl`)
- **Localization.get_available_locale_codes()**: warmup-safe method that returns language codes from directory names without triggering bundle compilation (`server/messages/localization.py`)
- **DocumentManager class**: `server/core/documents/manager.py`
  - Startup loading with auto-generated metadata for existing folders
  - Category queries with locale fallback (en -> slug)
  - Document filtering by category (all / specific / uncategorized)
  - Content read on demand, write with metadata timestamp update
  - Edit locks: acquire, release, conflict detection, stale cleanup (30min timeout)
  - Version history: backup on save, 5-version cap per locale
  - Create document and create category operations
- **Server wiring**: DocumentManager initialized and loaded on startup
- **Tests**: 29 DocumentManager tests, 4 new fluent languages tests in options menu suite
- **Locale completeness**: fixed missing .ftl files across 28 locales, added Serbian (sr)

---

## Chunk 2: Document Browsing (Read-Only)

Add the "Documents" menu item and let normal users browse and read documents.

### Scope
- Add "Documents" item to main menu in `server/core/server.py`
- Locale strings: documents menu title, "All documents", "Uncategorized", "Back", etc.
- `_show_documents_menu(user)`: list categories + "All documents" + "Uncategorized"
- `_show_documents_in_category(user, slug)`: list documents with titles for user's locale
- `_show_document_view(user, folder_name)`: read-only editbox with .md content
- Locale fallback: if user's locale not available, show source locale content
- Dispatch table entries for the new menus
- Tests for browsing flow (menu construction, locale fallback, content display)

### Files to modify
- `server/core/server.py` — menu handlers and dispatch entries
- `server/locales/en/main.ftl` — new locale strings

### Files to create
- None expected (all in server.py)

---

## Chunk 3: Transcriber Management

Admin UI for assigning transcribers and browsing transcriber data.

### Scope
- "View transcribers by language" menu: language list with user counts, drill into users per language
- "View transcribers by user" menu: user list with language counts, drill into languages per user
- Admin add/remove transcriber actions (uses existing DB methods: `add_transcriber`, `remove_transcriber`, `get_transcribers_for_language`, `get_user_transcriber_languages`)
- Validation: only users with a language in `fluent_languages` can be assigned as transcribers for that language
- Locale strings for transcriber menus and prompts
- Tests for transcriber menu flows

### Files to modify
- `server/core/server.py` — transcriber menu handlers
- `server/locales/en/main.ftl` — locale strings

---

## Chunk 4: Document Actions (Admin & Transcriber)

The action menu that appears when a transcriber or admin clicks a document.

### Scope
- Role-based behavior: normal users auto-view, transcribers/admins see action menu
- Action menu: View, Edit, Document settings
- Document settings submenu:
  - Change title (per locale)
  - Manage visibility (public/private toggles per locale)
  - Modify category list (admin, boolean toggle list)
  - Add translation (locale selection, title + content editboxes)
  - Remove translation (admin, confirmation with safeguards)
  - Delete document (admin, confirmation with translation count)
- Permission checks: transcribers limited to their assigned languages
- Locale strings for all prompts and confirmations
- Tests for action menu routing and permission checks

### Files to modify
- `server/core/server.py` — action menu handlers
- `server/locales/en/main.ftl` — locale strings

---

## Chunk 5: Document Editing

The in-app editor with edit locks, save/cancel, and version history integration.

### Scope
- `_show_document_editor(user, folder_name, locale)`: multiline editbox with current content
- Side-by-side source display: if editing a non-source locale, show source content in a read-only editbox
- Save handler: calls `DocumentManager.save_document_content()` (handles backup + lock release)
- Cancel handler: release edit lock, return to document actions
- Escape = cancel, with confirmation if content changed
- Lock acquisition on edit open, conflict message if locked by another user
- Locale strings for editor prompts, save/cancel confirmations, lock conflict messages
- Tests for edit flow, lock integration, save with version backup

### Files to modify
- `server/core/server.py` — editor handlers
- `server/locales/en/main.ftl` — locale strings

---

## Chunk 6: Document & Category Creation

Admin flows for creating new documents and categories.

### Scope
- New document flow: category selection -> title editbox -> content editbox -> auto-generate folder slug from title
- Slug collision detection with user-friendly error
- New category flow: slug editbox -> display name editbox
- Category management: rename (per locale), change sort method, delete (with document cleanup)
- Locale strings for creation flows
- Tests for creation flows and edge cases (duplicate slugs, empty input)

### Files to modify
- `server/core/server.py` — creation handlers
- `server/core/documents/manager.py` — possibly add slug generation helper, delete methods
- `server/locales/en/main.ftl` — locale strings
