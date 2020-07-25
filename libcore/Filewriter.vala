/* Game file reader class for gnonograms
 * Copyright (C) 2010-2017  Jeremy Wootten
 *
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 *  Author:
 *  Jeremy Wootten  < jeremwootten@gmail.com >
 */

namespace Gnonograms {
public class Filewriter : Object {
    /** PUBLIC **/
    public DateTime date { get; construct; }
    public uint rows { get; construct; }
    public uint cols { get; construct; }
    public string name { get; set; }
    public string[] row_clues { get; construct; }
    public string[] col_clues { get; construct; }
    public History? history { get; construct; }
    public Gtk.Window? parent { get; construct; }
    public string? game_path { get; private set; }

    public bool is_readonly { get; set; default = true;}
    public string author { get; set; default = "";}
    public string license { get; set; default = "";}
    public Difficulty difficulty { get; set; default = Difficulty.UNDEFINED;}
    public GameState game_state { get; set; default = GameState.UNDEFINED;}
    private bool save_solution = true;
    public My2DCellArray? solution { get; set; default = null;}
    public My2DCellArray? working { get; set; default = null;}

    /** PRIVATE **/
    private FileOutputStream? output_stream;
    private FileIOStream? stream;

    public Filewriter (Gtk.Window? parent,
                       Dimensions dimensions,
                       string[] row_clues,
                       string[] col_clues,
                       History? history) throws Error {

        Object (
            name: _(UNTITLED_NAME),
            parent: parent,
            rows: dimensions.rows (),
            cols: dimensions.cols (),
            row_clues: row_clues,
            col_clues: col_clues,
            history: history
        );
    }

    construct {
        date = new DateTime.now_local ();
    }

    /*** Writes minimum information required for valid game file ***/
    public void write_game_file (string? save_dir_path = null,
                                 File? save_file = null,
                                 string? _name = null) throws Error {

        if (_name != null) {
            name = _name;
        } else {
            name = _(UNTITLED_NAME);
        }

        File? game_file = null;
        if (save_file == null) {
            game_file = get_save_file (parent, save_dir_path);
        } else {
            game_file = save_file;
        }

        if (game_file == null) {
            throw new IOError.CANCELLED ("No game file selected");
        }

        if (!game_file.query_exists ()) {
            stream = game_file.create_readwrite  (FileCreateFlags.NONE, null);
        } else {
            stream = game_file.open_readwrite ();
        }

        if (stream == null) {
            throw new IOError.FAILED ("Could not open filestream to %s".printf (game_path));
        }

        output_stream = (FileOutputStream)stream.output_stream;
        if (name == null || name.length == 0) {
            throw new IOError.NOT_INITIALIZED ("No name to save");
        }

        output_stream.write ("[Description]\n".data);
        output_stream.write (("%s\n".printf (name)).data);
        output_stream.write (("%s\n".printf (author)).data);
        output_stream.write (("%s\n".printf (date.to_string ())).data);
        output_stream.write (("%u\n".printf (difficulty)).data);

        if (license == null || license.length > 0) {
            output_stream.write ("[License]\n".data);
            output_stream.write (("%s\n".printf (license)).data);
        }

        if (rows == 0 || cols == 0) {
            throw new IOError.NOT_INITIALIZED ("No dimensions to save");
        }

        output_stream.write ("[Dimensions]\n".data);
        output_stream.write (("%u\n".printf (rows)).data);
        output_stream.write (("%u\n".printf (cols)).data);

        if (row_clues.length == 0 || col_clues.length == 0) {
            throw new IOError.NOT_INITIALIZED ("No clues to save");
        }

        if (row_clues.length != rows || col_clues.length != cols) {
            throw new IOError.NOT_INITIALIZED ("Clues do not match dimensions");
        }

        output_stream.write ("[Row clues]\n".data);
        foreach (string s in row_clues) {
            output_stream.write (("%s\n".printf (s)).data);
        }

        output_stream.write ("[Column clues]\n".data);
        foreach (string s in col_clues) {
            output_stream.write (("%s\n".printf (s)).data);
        }

        if (solution != null && save_solution) {
            output_stream.write ("[Solution grid]\n".data);
            output_stream.write (("%s".printf (solution.to_string ())).data);
        }

        output_stream.write ("[Locked]\n".data);
        output_stream.write ((is_readonly.to_string () + "\n").data);
    }

    /*** Writes complete information to reload game state ***/
    public void write_position_file (string? save_dir_path = null,
                                     File? game_file = null,
                                     string? name = null) throws Error {

        if (working == null) {
            throw (new IOError.NOT_INITIALIZED ("No working grid to save"));
        } else if (game_state == GameState.UNDEFINED) {
            throw (new IOError.NOT_INITIALIZED ("No game state to save"));
        }

        write_game_file (save_dir_path, game_file, name);

        output_stream.write ("[Working grid]\n".data);
        output_stream.write (working.to_string ().data);
        output_stream.write ("[State]\n".data);
        output_stream.write ((game_state.to_string () + "\n").data);

        if (name != _(UNTITLED_NAME)) {
            output_stream.write ("[Original path]\n".data);
            output_stream.write ((game_file.get_path () + "\n").data);
        }

        if (history != null) {
            output_stream.write ("[History]\n".data);
            output_stream.write ((history.to_string () + "\n").data);
        }
    }

    private File? get_save_file (Gtk.Window? parent, string? save_dir_path) {

        var action = Gnonograms.FileChooserAction.SAVE_NO_SOLUTION;

        if (save_solution && solution != null) {
            action = Gnonograms.FileChooserAction.SAVE_WITH_SOLUTION;
        }

        bool with_solution = true;
        FilterInfo info = {_("Gnonogram puzzles"), {"*" + Gnonograms.GAMEFILEEXTENSION}};
        FilterInfo [] filters = {info};
        File? io_file = Utils.get_input_output_file (
                                parent,
                                action,
                                _("Name and save this puzzle"),
                                filters,
                                save_dir_path,
                                out with_solution // cannot use save_solution directly (will not compile)
                            );

        if (io_file != null) {
            save_solution = with_solution;

            if (!save_solution && solution != null) {
                save_solution = !Utils.show_confirm_dialog (_("Confirm save without solution"),
                                                            _("Do not save computer insoluble clues without solution"),
                                                            parent);
            }
        }

        return io_file;
    }
}
}
