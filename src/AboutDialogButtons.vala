/*
 *  Copyright (C) 2011-2013 Adrien Plazas <kekun.plazas@laposte.net>
 *
 *  Most of this file are part of Granite 0.3.1.
 *  Modifications were added by Leonid Kostrykin <void@evoid.de>
 *
 *  This program or library is free software; you can redistribute it
 *  and/or modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General
 *  Public License along with this library; if not, write to the
 *  Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301 USA.
 */

using Gtk;

public class AboutDialogButtons {

    /**
     * The URL for the link to the website of the program.
     */
    public string help {
        set {
            _help = value;
            help_button.sensitive = !(_help == null || _help == "");
        }
        get { return _help; }
    }
    string _help = "";

    /**
     * The URL for the link to the website of the program.
     */
    public string translate {
        set {
            _translate = value;
            translate_button.sensitive = !(_translate == null || _translate == "");
        }
        get { return _translate; }
    }
    string _translate = "";

    /**
     * The URL for the link to the website of the program.
     */
    public string bug {
        set {
            _bug = value;
            bug_button.sensitive = !(_bug == null || _bug == "");
        }
        get { return _bug; }
    }
    string _bug = "";

    private Button help_button;
    private Button translate_button;
    private Button bug_button;

    public AboutDialogButtons ( Granite.GtkPatch.AboutDialog dlg ) {
        /* help button */
        help_button = new Button.with_label ("?");
        help_button.get_style_context ().add_class ("help_button");

        help_button.halign = Gtk.Align.CENTER;
        help_button.clicked.connect (() => { dlg.activate_link(help); });

        /* Circular help button */
        help_button.size_allocate.connect ( (alloc) => {
            help_button.set_size_request (alloc.height, -1);
        });

        /* translate button */
        translate_button = new Button.with_label("Suggest Translations");
        translate_button.clicked.connect ( () => { dlg.activate_link(translate); });

        /* bug button */
        bug_button = new Button.with_label ("Report a Problem");
        bug_button.clicked.connect (() => {
            try {
                GLib.Process.spawn_command_line_async ("apport-bug %i".printf (Posix.getpid ()));
            } catch (Error e) {
                warning ("Could Not Launch 'apport-bug'.");
                dlg.activate_link (bug);
            }
        });
    }

    public void put_into( ButtonBox action_area )
    {
        action_area.pack_end (help_button, false, false, 0);
        action_area.set_child_secondary (help_button, true);
        action_area.set_child_non_homogeneous (help_button, true);
        action_area.pack_start (translate_button, false, false, 0);
        action_area.pack_start (bug_button, false, false, 0);
        action_area.reorder_child (bug_button, 0);
        action_area.reorder_child (translate_button, 0);
    }
}

