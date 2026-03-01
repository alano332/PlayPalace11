"""Transcriber management menus for the PlayPalace server."""

from typing import TYPE_CHECKING

from ..users.network_user import NetworkUser
from ..users.base import MenuItem, EscapeBehavior, TrustLevel
from ...messages.localization import Localization

if TYPE_CHECKING:
    from ...persistence.database import Database


class TranscriberRoleMixin:
    """Provide transcriber assignment and management menus.

    Expected attributes:
        _db: Database instance.
        _user_states: dict[str, dict] of user menu states.
        _show_documents_menu(user): Method to show the documents menu.
    """

    _db: "Database"
    _user_states: dict[str, dict]

    # -- Transcriber management menus --

    def _show_transcribers_by_language(self, user: NetworkUser) -> None:
        """Show the language list with transcriber counts per language."""
        from server.core.ui.common_flows import show_language_menu

        all_transcribers = self._db.get_all_transcribers()
        # Count transcribers per language
        lang_counts: dict[str, int] = {}
        for langs in all_transcribers.values():
            for lang in langs:
                lang_counts[lang] = lang_counts.get(lang, 0) + 1

        status_labels = {}
        for code in Localization.get_available_locale_codes():
            count = lang_counts.get(code, 0)
            key = "transcribers-language-users-one" if count == 1 else "transcribers-language-users"
            # We only need the count part, not the full label with language name
            label = f"({count} {'user' if count == 1 else 'users'})"
            status_labels[code] = label

        if show_language_menu(
            user,
            highlight_active_locale=False,
            status_labels=status_labels,
            on_select=self._on_transcribers_by_language_select,
            on_back=lambda u: self._show_documents_menu(u),
        ):
            self._user_states[user.username] = {"menu": "language_menu"}

    async def _on_transcribers_by_language_select(
        self, user: NetworkUser, lang_code: str
    ) -> None:
        """Handle language selection in transcribers-by-language view."""
        self._show_transcribers_for_language(user, lang_code)

    def _show_transcribers_for_language(
        self, user: NetworkUser, lang_code: str
    ) -> None:
        """Show list of transcribers assigned to a language."""
        usernames = self._db.get_transcribers_for_language(lang_code)
        is_admin = user.trust_level.value >= TrustLevel.ADMIN.value

        if not usernames and not is_admin:
            user.speak_l("transcribers-no-users")
            self._show_transcribers_by_language(user)
            return

        items = []
        for username in usernames:
            items.append(MenuItem(text=username, id=f"user_{username}"))
        if is_admin:
            items.append(
                MenuItem(
                    text=Localization.get(user.locale, "transcribers-add-users"),
                    id="add_users",
                )
            )
        items.append(
            MenuItem(text=Localization.get(user.locale, "back"), id="back")
        )
        user.show_menu(
            "transcribers_for_language_menu",
            items,
            multiletter=True,
            escape_behavior=EscapeBehavior.SELECT_LAST,
        )
        self._user_states[user.username] = {
            "menu": "transcribers_for_language_menu",
            "lang_code": lang_code,
        }

    async def _handle_transcribers_for_language_selection(
        self, user: NetworkUser, selection_id: str, state: dict
    ) -> None:
        """Handle selection in the transcribers-for-language menu."""
        lang_code = state.get("lang_code", "")
        adding = state.get("adding_users", False)
        if selection_id == "back":
            if adding:
                self._show_transcribers_for_language(user, lang_code)
            else:
                self._show_transcribers_by_language(user)
        elif selection_id == "add_users":
            self._show_add_transcriber_users(user, lang_code)
        elif selection_id.startswith("toggle_") and adding:
            target_username = selection_id[7:]
            self._toggle_transcriber_for_language(user, target_username, lang_code)
        elif selection_id.startswith("user_"):
            target_username = selection_id[5:]
            if user.trust_level.value >= TrustLevel.ADMIN.value:
                self._show_transcriber_remove_confirm(user, target_username, lang_code)
            else:
                self._show_transcribers_for_language(user, lang_code)

    def _show_transcriber_remove_confirm(
        self, user: NetworkUser, target_username: str, lang_code: str
    ) -> None:
        """Ask admin to confirm removing a transcriber from a language."""
        from server.core.ui.common_flows import show_yes_no_menu

        lang_name = Localization.get(user.locale, f"language-{lang_code}")
        question = Localization.get(
            user.locale, "transcribers-remove-confirm",
            user=target_username, language=lang_name,
        )
        show_yes_no_menu(user, "transcriber_remove_confirm", question)
        self._user_states[user.username] = {
            "menu": "transcriber_remove_confirm",
            "target_username": target_username,
            "lang_code": lang_code,
        }

    async def _handle_transcriber_remove_confirm(
        self, user: NetworkUser, selection_id: str, state: dict
    ) -> None:
        """Handle transcriber removal confirmation."""
        lang_code = state.get("lang_code", "")
        target_username = state.get("target_username", "")
        if selection_id == "yes":
            self._db.remove_transcriber_assignment(target_username, lang_code)
            lang_name = Localization.get(user.locale, f"language-{lang_code}")
            user.speak_l(
                "transcribers-removed",
                user=target_username, language=lang_name,
            )
        self._show_transcribers_for_language(user, lang_code)

    def _show_add_transcriber_users(
        self, user: NetworkUser, lang_code: str
    ) -> None:
        """Show toggle list of eligible users to add as transcribers for a language."""
        existing = set(self._db.get_transcribers_for_language(lang_code))
        # Get all approved users (non-admin + admin) and filter by fluent languages
        all_users = self._db.get_non_admin_users() + self._db.get_admin_users()
        on_label = Localization.get(user.locale, "option-on")
        off_label = Localization.get(user.locale, "option-off")
        items = []
        for u in sorted(all_users, key=lambda r: r.username.lower()):
            if lang_code not in u.fluent_languages:
                continue
            status = on_label if u.username in existing else off_label
            items.append(
                MenuItem(
                    text=f"{u.username} {status}",
                    id=f"toggle_{u.username}",
                )
            )
        if not items:
            user.speak_l("transcribers-no-eligible-users")
            self._show_transcribers_for_language(user, lang_code)
            return

        items.append(
            MenuItem(text=Localization.get(user.locale, "back"), id="back")
        )
        user.show_menu(
            "transcribers_for_language_menu",
            items,
            multiletter=True,
            escape_behavior=EscapeBehavior.SELECT_LAST,
        )
        self._user_states[user.username] = {
            "menu": "transcribers_for_language_menu",
            "lang_code": lang_code,
            "adding_users": True,
        }

    def _toggle_transcriber_for_language(
        self, user: NetworkUser, target_username: str, lang_code: str
    ) -> None:
        """Toggle a user's transcriber assignment for a language."""
        existing = self._db.get_transcribers_for_language(lang_code)
        lang_name = Localization.get(user.locale, f"language-{lang_code}")
        if target_username in existing:
            self._db.remove_transcriber_assignment(target_username, lang_code)
            user.play_sound("checkbox_list_off.wav")
        else:
            # Verify the user has this language in fluent_languages
            fluent = self._db.get_user_fluent_languages(target_username)
            if lang_code not in fluent:
                user.speak_l(
                    "transcribers-not-fluent",
                    user=target_username, language=lang_name,
                )
                return
            self._db.add_transcriber_assignment(target_username, lang_code)
            user.play_sound("checkbox_list_on.wav")
        self._show_add_transcriber_users(user, lang_code)

    # -- Transcribers by user --

    def _show_transcribers_by_user(self, user: NetworkUser) -> None:
        """Show list of transcriber users with language counts."""
        all_transcribers = self._db.get_all_transcribers()

        if not all_transcribers and user.trust_level.value < TrustLevel.ADMIN.value:
            user.speak_l("transcribers-no-transcribers")
            self._show_documents_menu(user)
            return

        items = []
        for username in sorted(all_transcribers.keys(), key=str.lower):
            count = len(all_transcribers[username])
            label = f"{username} ({count} {'language' if count == 1 else 'languages'})"
            items.append(MenuItem(text=label, id=f"user_{username}"))

        items.append(
            MenuItem(text=Localization.get(user.locale, "back"), id="back")
        )
        user.show_menu(
            "transcribers_by_user_menu",
            items,
            multiletter=True,
            escape_behavior=EscapeBehavior.SELECT_LAST,
        )
        self._user_states[user.username] = {"menu": "transcribers_by_user_menu"}

    async def _handle_transcribers_by_user_selection(
        self, user: NetworkUser, selection_id: str, state: dict
    ) -> None:
        """Handle selection in transcribers-by-user menu."""
        if selection_id == "back":
            self._show_documents_menu(user)
        elif selection_id.startswith("user_"):
            target_username = selection_id[5:]
            self._show_transcriber_user_languages(user, target_username)

    def _show_transcriber_user_languages(
        self, user: NetworkUser, target_username: str
    ) -> None:
        """Show languages assigned to a specific transcriber."""
        lang_codes = self._db.get_transcriber_languages(target_username)
        is_admin = user.trust_level.value >= TrustLevel.ADMIN.value

        if not lang_codes and not is_admin:
            user.speak_l("transcribers-no-languages")
            self._show_transcribers_by_user(user)
            return

        items = []
        for code in lang_codes:
            name = Localization.get(user.locale, f"language-{code}")
            items.append(MenuItem(text=name, id=f"lang_{code}"))
        if is_admin:
            items.append(
                MenuItem(
                    text=Localization.get(user.locale, "transcribers-add-languages"),
                    id="add_languages",
                )
            )
        items.append(
            MenuItem(text=Localization.get(user.locale, "back"), id="back")
        )
        user.show_menu(
            "transcriber_user_languages_menu",
            items,
            multiletter=True,
            escape_behavior=EscapeBehavior.SELECT_LAST,
        )
        self._user_states[user.username] = {
            "menu": "transcriber_user_languages_menu",
            "target_username": target_username,
        }

    async def _handle_transcriber_user_languages_selection(
        self, user: NetworkUser, selection_id: str, state: dict
    ) -> None:
        """Handle selection in a transcriber's language list."""
        target_username = state.get("target_username", "")
        if selection_id == "back":
            self._show_transcribers_by_user(user)
        elif selection_id == "add_languages":
            self._show_add_transcriber_languages(user, target_username)
        elif selection_id.startswith("lang_"):
            lang_code = selection_id[5:]
            if user.trust_level.value >= TrustLevel.ADMIN.value:
                self._show_transcriber_remove_lang_confirm(user, target_username, lang_code)
            else:
                self._show_transcriber_user_languages(user, target_username)

    def _show_transcriber_remove_lang_confirm(
        self, user: NetworkUser, target_username: str, lang_code: str
    ) -> None:
        """Ask admin to confirm removing a language from a transcriber."""
        from server.core.ui.common_flows import show_yes_no_menu

        lang_name = Localization.get(user.locale, f"language-{lang_code}")
        question = Localization.get(
            user.locale, "transcribers-remove-lang-confirm",
            user=target_username, language=lang_name,
        )
        show_yes_no_menu(user, "transcriber_remove_lang_confirm", question)
        self._user_states[user.username] = {
            "menu": "transcriber_remove_lang_confirm",
            "target_username": target_username,
            "lang_code": lang_code,
        }

    async def _handle_transcriber_remove_lang_confirm(
        self, user: NetworkUser, selection_id: str, state: dict
    ) -> None:
        """Handle language removal confirmation."""
        target_username = state.get("target_username", "")
        lang_code = state.get("lang_code", "")
        if selection_id == "yes":
            self._db.remove_transcriber_assignment(target_username, lang_code)
            lang_name = Localization.get(user.locale, f"language-{lang_code}")
            user.speak_l(
                "transcribers-removed",
                user=target_username, language=lang_name,
            )
        self._show_transcriber_user_languages(user, target_username)

    def _show_add_transcriber_languages(
        self, user: NetworkUser, target_username: str
    ) -> None:
        """Show language menu filtered to the user's unassigned fluent languages."""
        from server.core.ui.common_flows import show_language_menu

        fluent = self._db.get_user_fluent_languages(target_username)
        assigned = set(self._db.get_transcriber_languages(target_username))
        available = [code for code in fluent if code not in assigned]

        if not available:
            user.speak_l("transcribers-no-eligible-languages")
            self._show_transcriber_user_languages(user, target_username)
            return

        on_label = Localization.get(user.locale, "option-on")
        off_label = Localization.get(user.locale, "option-off")
        # All shown languages are currently off (not assigned)
        status_labels = {code: off_label for code in available}

        if show_language_menu(
            user,
            highlight_active_locale=False,
            lang_codes=available,
            status_labels=status_labels,
            on_select=lambda u, lc: self._toggle_transcriber_language_for_user(u, target_username, lc),
            on_back=lambda u: self._show_transcriber_user_languages(u, target_username),
        ):
            self._user_states[user.username] = {
                "menu": "language_menu",
                "target_username": target_username,
            }

    def _toggle_transcriber_language_for_user(
        self, user: NetworkUser, target_username: str, lang_code: str
    ) -> None:
        """Toggle a language assignment for a transcriber user."""
        assigned = self._db.get_transcriber_languages(target_username)
        if lang_code in assigned:
            self._db.remove_transcriber_assignment(target_username, lang_code)
            user.play_sound("checkbox_list_off.wav")
        else:
            self._db.add_transcriber_assignment(target_username, lang_code)
            user.play_sound("checkbox_list_on.wav")
        self._show_add_transcriber_languages(user, target_username)
