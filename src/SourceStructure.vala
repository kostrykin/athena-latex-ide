namespace SourceStructure
{

    public enum Feature { LABEL, BIB_ENTRY, COMMAND }
    public enum SearchResult { ALL_VISITED, CANCELED, ALREADY_VISITED }

    public class Node : Object
    {
        private Gee.Set< weak InnerNode > parents = new Gee.HashSet< InnerNode* >();
        public Gee.Map< Feature, string > features { get; private set; default = new Gee.HashMap< Feature, string >(); }

        #if DEBUG
        public static uint _debug_instance_counter = 0;

        public Node()
        {
            ++_debug_instance_counter;
        }

        ~Node()
        {
            --_debug_instance_counter;
        }
        #endif

        public static Gee.Set< Node > empty_visited_nodes_set()
        {
            return new Gee.HashSet< Node >();
        }

        public delegate bool Visitor( Node node );
        public virtual SearchResult search_feature( Feature feature, Visitor visit, Gee.Set< Node > visited = empty_visited_nodes_set() )
        {
            if( this in visited ) return SearchResult.ALREADY_VISITED;
            if( feature in features.keys )
            {
                if( !visit( this ) ) return SearchResult.CANCELED;
            }
            return SearchResult.ALL_VISITED;
        }

        public void remove_from_parent( InnerNode parent )
            requires( (bool)( parent in parents ) )
        {
            remove_parent( parent );
            parent.drop_child( this );
        }

        public void remove_from_parents()
        {
            foreach( var p in parents )
            {
                p.weak_unref( drop_parent );
                p.drop_child( this );
            }
            parents.clear();
        }

        protected void add_parent( InnerNode parent )
        {
            parents.add( parent );
            parent.weak_ref( drop_parent );
        }

        protected void remove_parent( InnerNode parent )
        {
            parent.weak_unref( drop_parent );
            drop_parent( parent );
        }

        private void drop_parent( Object parent )
        {
            parents.remove( (InnerNode) parent );
        }
    }

    public interface InnerNode : Node
    {
        /**
         * Only removes the `child` without changing it's parents.
         */
        internal abstract void drop_child( Node child );
    }

    public class SimpleNode : Node, InnerNode
    {
        private Gee.List< Node > children = new Gee.LinkedList< Node >();

        public int children_count { get { return children.size; } }

        internal void drop_child( Node child )
        {
            children.remove( child );
        }

        public void add_child( Node child )
            requires( !( child in children ) )
        {
            child.add_parent( this );
            children.add( child );
        }

        public void remove_child( Node child )
            requires( (bool)( child in children ) )
        {
            child.remove_from_parent( this );
        }

        public void remove_all_children()
        {
            foreach( var c in children ) c.remove_parent( this );
            children.clear();
        }

        public override SearchResult search_feature( Feature feature, Node.Visitor visit, Gee.Set< Node > visited = Node.empty_visited_nodes_set() )
        {
            switch( base.search_feature( feature, visit, visited ) )
            {

            case SearchResult.CANCELED:
                return SearchResult.CANCELED;

            case SearchResult.ALREADY_VISITED:
                return SearchResult.ALREADY_VISITED;

            case SearchResult.ALL_VISITED:
                foreach( var child in children )
                {
                    if( child.search_feature( feature, visit, visited ) == SearchResult.CANCELED )
                    {
                        return SearchResult.CANCELED;
                    }
                }
                return SearchResult.ALL_VISITED;

            default:
                assert_not_reached();

            }
        }
    }

    public class FileReferenceNode : Node, InnerNode
    {
        private SourceFileView parent_view;
        private string path;
        private SourceAnalyzer.FileReferenceType path_type;
        private Editor editor { get { return parent_view.editor; } }

        private string?   _abs_path = null;
        private string get_abs_path()
        {
            if( _abs_path == null ) _abs_path = parent_view.resolve_path( path, path_type );
            return _abs_path;
        }

        public class Resolution
        {
            public weak Node node { get; private set; }
            public SourceFileManager.SourceFile file { get; private set; }

            public Resolution( Node node, SourceFileManager.SourceFile file )
            {
                this.node = node;
                this.file = file;
            }
        }
        public Resolution? resolution { public get; private set; }

        internal void drop_child( Node child )
        {
            if( resolution != null )
            {
                resolution.node.weak_unref( reset );
                resolution = null;
            }
        }

        public FileReferenceNode( SourceFileView parent_view, string path, SourceAnalyzer.FileReferenceType path_type )
        {
            this.parent_view = parent_view;
            this.path = path;
            this.path_type = path_type;

            weak FileReferenceNode weak_this = this;

            editor.file_saved .connect( weak_this.handle_file_saved  );
            editor.file_opened.connect( weak_this.handle_file_opened );
        }

        /**
         * When another file is saved, then it's path migh have changed,
         * so try to use it's path to resolve this reference,
         * unless it's already resolved.
         *
         * For the same reason, if the parent file is saved and the reference
         * path type isn't absolute, the reference needs to be re-evaluated.
         */
        private void handle_file_saved( SourceFileManager.SourceFile file )
        {
            if( file != parent_view.file )
            {
                resolve_through_file( file );
            }
            else
            {
                reset();
                resolve();
            }
        }

        /**
         * When a file is opened in the editor,
         * try to resolve this reference through that file,
         * unless it's already resolved.
         */
        private void handle_file_opened( SourceFileManager.SourceFile file )
        {
            resolve_through_file( file );
        }

        public void reset()
        {
            if( path_type != SourceAnalyzer.FileReferenceType.ABSOLUTE ) _abs_path = null;
            if( is_resolved )
            {
                resolution.node.remove_from_parent( this );
            }
        }

        /**
         * Attempts to resolve this reference through `file`.
         *
         * Returns `false` only if this attempt fails *and*
         * the referenced file appears not to exist yet.
         */
        private bool resolve_through_file( SourceFileManager.SourceFile file )
        {
            if( !is_resolved && file.path != null && file != parent_view.file )
            {
                var path = get_abs_path();
                if( path != null )
                {
                    try
                    {
                        if( Utils.same_files( path, file.path ) )
                        {
                            weak FileReferenceNode weak_this = this;
                            var view = editor.get_source_view( file );
                            resolution = new Resolution( view.structure, file );
                            resolution.node.add_parent( this );
                            resolution.node.weak_ref( weak_this.reset );
                        }
                    }
                    catch( Error err )
                    {
                        /* No information could be queried for `path`.
                         * This behaviour is independent of the `candidate_path`,
                         * hence it's fair to expect it for each subsequent candidate.
                         */
                        return false;
                    }
                }
            }
            return true;
        }

        bool is_resolved { public get { assert( resolution == null || resolution.node != null ); return resolution != null; } }

        public void resolve()
        {
            if( !is_resolved )
            {
                foreach( var view in editor.get_source_views() )
                {
                    if( view == parent_view ) continue;
                    if( !resolve_through_file( view.file ) || is_resolved ) break;
                }
            }
        }

        public override SearchResult search_feature( Feature feature, Node.Visitor visit, Gee.Set< Node > visited = Node.empty_visited_nodes_set() )
        {
            var base_result = base.search_feature( feature, visit, visited );
            if( base_result == SearchResult.ALL_VISITED && is_resolved )
            {
                return resolution.node.search_feature( feature, visit, visited );
            }
            else return base_result;
        }
    }

    public class UsePackageNode : Node
    {
        private static Gee.Collection< string > EMPTY_COMMANDS_LIST = new Gee.ArrayList< string >();
        private weak SourceFileManager.SourceFile file;
        private string? current_dir_path;
        private string  package_name;
        private PackageAnalyzer.Result? package_info;

        public UsePackageNode( SourceFileView view, string package_name )
            requires( package_name.length > 0 )
        {
            base();
            this.file = view.file;
            this.package_name = package_name;

            features[ Feature.COMMAND ] = ""; // ensurs this node is found when graph is searched for `Feature.COMMAND` nodes

            weak UsePackageNode weak_this = this;
            view.editor.file_saved.connect( weak_this.handle_file_saved );
        }

        public void update( bool force = false )
        {
            string? dir_path = file.path != null ? Path.get_dirname( file.path ) : null;
            if( dir_path == current_dir_path && !force ) return;
            current_dir_path = dir_path;

            var request = new PackageAnalyzer.Request( package_name, current_dir_path );
            weak UsePackageNode weak_this = this;
            request.done.connect( weak_this.update_package_info );
            PackageAnalyzer.instance.enqueue( request );
        }

        private void update_package_info( PackageAnalyzer.Result package_info )
        {
            this.package_info = package_info;
        }

        private void handle_file_saved( SourceFileManager.SourceFile file )
        {
            if( file == this.file ) update();
        }

        public Gee.Collection< string > commands
        {
            get
            {
                return package_info != null ? package_info.commands : EMPTY_COMMANDS_LIST;
            }
        }
    }

}

