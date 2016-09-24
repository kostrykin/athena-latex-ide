public class CommandCompletionProvider: Object, Gtk.SourceCompletionProvider
{

    /**
     * A list of built-in LaTeX commands, which will be proposed to the user.
     *
     * Notably, this isn't a full list, and there is no intention that it should be complete,
     * because there are too many built-commands, most of which nobody ever uses.
     *
     * A full list can be viewed by typing `textoc source2e` on a terminal.
     */
    private static string[] built_in_commands =
    {
        "addtocounter",
        "alpha",
        "approx",
        "ast",
        "author",
        "bar",
        "baselineskip",
        "baselinestretch",
        "begin",
        "beta",
        "bibliography",
        "bibliographystyle",
        "bigcirc",
        "bigcap",
        "bigcup",
        "bigskip",
        "bigvee",
        "bigwedge",
        "centering",
        "chapter",
        "cdot",
        "chi",
        "circ",
        "cite",
        "clearpage",
        "cline",
        "cap",
        "cup",
        "date",
        "ddot",
        "def",
        "delta",
        "Delta",
        "diamond",
        "div",
        "documentclass",
        "dot",
        "dotfill",
        "emph",
        "emptyset",
        "end",
        "enskip",
        "enspace",
        "epsilon",
        "eqref",
        "equiv",
        "eta",
        "exists",
        "fbox",
        "fboxrule",
        "fill",
        "footnote",
        "footnotemark",
        "footnotesize",
        "footnotetext",
        "forall",
        "frac",
        "gamma",
        "Gamma",
        "geq",
        "gg",
        "gneq",
        "hat",
        "hfill",
        "hline",
        "hrulefill",
        "hspace",
        "huge",
        "Huge",
        "Im",
        "in",
        "include",
        "infty",
        "input",
        "iota",
        "item",
        "kappa",
        "label",
        "lambda",
        "Lambda",
        "large",
        "Large",
        "LARGE",
        "LaTeX",
        "left",
        "Leftrightarrow",
        "Leftarrow",
        "leq",
        "let",
        "limits",
        "ll",
        "lneq",
        "maketitle",
        "mathbb",
        "mathbf",
        "mathrm",
        "mathsf",
        "mbox",
        "mp",
        "medskip",
        "middle",
        "mu",
        "nabla",
        "neg",
        "newcounter",
        "newline",
        "newpage",
        "newcommand",
        "newenvironment",
        "ni",
        "nopagebreak",
        "normalsize",
        "not",
        "nu",
        "odot",
        "omega",
        "Omega",
        "ominus",
        "oplus",
        "oslash",
        "otimes",
        "overline",
        "pagebreak",
        "pageref",
        "pagestyle",
        "paragraph",
        "parallel",
        "parbox",
        "part",
        "partial",
        "phi",
        "Phi",
        "pi",
        "Pi",
        "pm",
        "perp",
        "prec",
        "preceq",
        "prod",
        "propto",
        "protect",
        "psi",
        "Psi",
        "qquad",
        "quad",
        "quote",
        "raggedleft",
        "raggedright",
        "raisebox",
        "Re",
        "ref",
        "refstepcounter",
        "renewcommand",
        "renewenvironment",
        "rho",
        "right",
        "Rightarrow",
        "scriptsize",
        "section",
        "setcounter",
        "setlength",
        "setminus",
        "sigma",
        "Sigma",
        "sim",
        "simeq",
        "small",
        "stepcounter",
        "subsection",
        "subset",
        "subseteq",
        "supset",
        "supseteq",
        "subsubsection",
        "succ",
        "succeq",
        "sum",
        "tableofcontents",
        "tau",
        "TeX",
        "text",
        "textbf",
        "textit",
        "textmd",
        "textrm",
        "textsc",
        "textsl",
        "textsf",
        "texttt",
        "textup",
        "thanks",
        "thepage",
        "theta",
        "Theta",
        "thispagestyle",
        "tilde",
        "times",
        "tiny",
        "title",
        "today",
        "underline",
        "upsilon",
        "Upsilon",
        "usepackage",
        "varepsilon",
        "vartheta",
        "varpi",
        "varrho",
        "varsigma",
        "varphi",
        "vfill",
        "vee",
        "vec",
        "vspace",
        "wedge",
        "widetilde",
        "xi",
        "Xi",
        "zeta"
    };

    private static Regex acceptance_pattern;
    static construct
    {
        try
        {
            acceptance_pattern = new Regex( "[A-Za-z0-9_:]*$", RegexCompileFlags.ANCHORED | RegexCompileFlags.DOLLAR_ENDONLY );
        }
        catch( RegexError err )
        {
            critical( err.message );
        }
    }

    public weak Editor editor { get; private set; }
    private string? command_input;

    public CommandCompletionProvider( Editor editor )
    {
        this.editor = editor;
    }

    public virtual string get_name()
    {
        return "Commands";
    }

    public virtual bool match( Gtk.SourceCompletionContext context )
    {
        Gtk.TextIter line_start = Gtk.TextIter();
        line_start.assign( context.iter );
        line_start.set_line_offset( 0 );

        Gtk.TextIter c0, c1;
        if( context.iter.backward_search( "\\", 0, out c0, out c1, line_start ) )
        {
            var text = c1.get_text( context.iter );
            if( acceptance_pattern.match_all( text ) )
            {
                command_input = text;
                return true;
            }
        }
        return false;
    }

    private void process_candidate( Gtk.SourceCompletionContext context, Gee.Set< Gtk.SourceCompletionItem > proposals, string command_input, string command )
    {
        if( command.has_prefix( command_input ) )
        {
            proposals.add( new Gtk.SourceCompletionItem( command, command, null, null ) );
        }
    }

    public virtual void populate( Gtk.SourceCompletionContext context )
    {
        var proposals = new Gee.TreeSet< Gtk.SourceCompletionItem >( ( a, b ) => { return a.text.collate( b.text ); } );
        assert( editor.structure != null );
        editor.structure.search_feature( SourceStructure.Feature.COMMAND, ( node ) =>
            {
                if( node is SourceStructure.UsePackageNode )
                {
                    var pkg_node = node as SourceStructure.UsePackageNode;
                    foreach( var command in pkg_node.commands ) process_candidate( context, proposals, command_input, command );
                }
                else
                {
                    var command = node.features[ SourceStructure.Feature.COMMAND ];
                    if( command.length > 0 ) process_candidate( context, proposals, command_input, command );
                }
                return true;
            }
        );
        foreach( var command in built_in_commands ) process_candidate( context, proposals, command_input, command );
        var proposals_list = new List< Gtk.SourceCompletionItem >();
        foreach( var proposal in proposals ) proposals_list.append( proposal );
        context.add_proposals( this, proposals_list, true );
    }

}

