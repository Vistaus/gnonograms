/* Utility functions for gnonograms
 * Copyright (C) 2010-2017  Jeremy Wootten
 *
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Author:
 *  Jeremy Wootten <jeremywootten@gmail.com>
 */
public class Gnonograms.GameChooser : Object {
    public string root_path  { get; construct; }
    public Gtk.FileChooserAction action  { get; construct; }
    public string? suggested_name  { get; construct; }
    public Gtk.Window parent { get; construct; }

    private File root_folder;
    private Gtk.ListBox game_filenames;
    private Gtk.Entry filename_entry;
    private Gtk.Dialog dialog;

    public GameChooser (Gtk.Window _parent,
                          string _root_path,
                          Gtk.FileChooserAction _action,
                          string? _suggested_name = null) {
        Object (
            root_path : _root_path,
            action : _action,
            suggested_name : _suggested_name,
            parent : _parent
        );
    }

    construct {
        var game_list_label = new Gtk.Label (_("Saved Games"));
        game_filenames = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE,
            margin = 12
        };

        game_filenames.set_sort_func (compare_rows);

        var placeholder = _("Enter game filename or select");
        filename_entry = new Gtk.Entry () {
            placeholder_text = placeholder,
            margin = 12,
            width_chars = placeholder.length
        };

        dialog = new Gtk.Dialog () {
            title = action == Gtk.FileChooserAction.SAVE ? _("Save game") : _("Open Game"),
            modal = true,
            deletable = false
        };

        dialog.set_transient_for (parent);

        var cancel_button = (Gtk.Button)(dialog.add_button (
            _("Cancel"),
            Gtk.ResponseType.CANCEL
        ));

        var accept_button = (Gtk.Button)(dialog.add_button (
            action == Gtk.FileChooserAction.SAVE ? _("Save") : _("Open"),
            Gtk.ResponseType.ACCEPT
        ));

        accept_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var vbox = dialog.get_content_area ();

        vbox.add (filename_entry);
        vbox.add (game_filenames);

        root_folder = File.new_for_path (root_path);

        dialog.realize.connect (() => {
            populate_list.begin ();
        });

        game_filenames.row_selected.connect ((row) => {
            filename_entry.text = ((Gtk.Label)(row.get_child ())).label;
        });

        dialog.show_all ();

        cancel_button.grab_focus ();
    }

    public File? run () {
        var response = dialog.run ();
        var filename = filename_entry.text;
        dialog.destroy ();
        if (response == Gtk.ResponseType.ACCEPT) {
            if (filename_entry.text != null) {
                var name = validate (filename);
                return File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S, root_path, name));
            }
        }

        return null;
    }

    private async void populate_list () {
        FileInfo? info = null;
        FileEnumerator? enumerator = null;

        try {
            enumerator = root_folder.enumerate_children (
                "standard::*",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        } catch (GLib.Error e) {
            warning ("Could not get enumerator - %s", e.message);
        }

        try {
           while ((info = enumerator.next_file ()) != null) {
                var name = info.get_attribute_string (FileAttribute.STANDARD_DISPLAY_NAME);
                if (name != null && name.has_suffix (Gnonograms.GAMEFILEEXTENSION)) {
                    add_filename (name);
                }
            }
        } catch (GLib.Error e) {
            warning ("Error enumerating %s", e.message);
        }
    }

    private void add_filename (string name) {
        var row = new Gtk.ListBoxRow () {
            activatable = false,
            selectable = true
        };

        var child = new Gtk.Label (name) {
            xalign = 0.0f
        };

        row.add (child);
        row.show_all ();
        game_filenames.add (row);
    }

    private int compare_rows (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        return strcmp (((Gtk.Label)(row1.get_child ())).label, ((Gtk.Label)(row2.get_child ())).label);
    }

    private string validate (string filename) {
        var valid_name = filename;

        if (!valid_name.has_suffix (Gnonograms.GAMEFILEEXTENSION)) {
            valid_name += ".gno";
        }

        make_file_name_valid_for_dest_fs (valid_name);
        return valid_name;
    }

    /* Copied from pantheon-files */
    private const string FAT_FORBIDDEN_CHARACTERS = "/:;*?\"<>";
    private void make_file_name_valid_for_dest_fs (string filename) {
        FileInfo? dest_fs_type_info = null;
        try {
            dest_fs_type_info = root_folder.query_filesystem_info ("filesystem::*");
        } catch (Error e) {
            warning ("Error getting filesystem info %s", e.message);
            return;
        }

        var dest_fs_type = dest_fs_type_info.get_attribute_string (FileAttribute.FILESYSTEM_TYPE);
        if (dest_fs_type == null) {
            return;
        }

        switch (dest_fs_type) {
            case "fat":
            case "vfat":
            case "msdos":
            case "msdosfs":
                str_replace (filename, FAT_FORBIDDEN_CHARACTERS, '_');
                int old_len = filename.length;
                for (int i = 0; i < old_len; i++) {
                    if (filename[i] != ' ') {
                        filename._chomp ();
                        break;
                    }
                }

                break;

            default:
                break;
        }
    }

    private void str_replace (string str, string chars_to_replace, char replacement) {
        for (int i = 0; str[i] != '\0'; i++) {
            if (chars_to_replace.index_of_char (str[i]) != -1) {
                str.data[i] = replacement;
            }
        }
    }
}

