namespace SourceStructure
{

    public enum Feature { LABEL, BIB_ENTRY }
    public enum SearchResult { ALL_VISITED, CANCELED, ALREADY_VISITED }

    public class Node
    {
        public weak InnerNode? parent { public get; protected set; default = null; }
        public Gee.Map< Feature, string > features { public get; private set; default = new Gee.HashMap< Feature, string >(); }

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

        public bool remove_from_parent()
        {
            if( parent != null )
            {
                parent.children.remove( this );
                parent = null;
                return true;
            }
            else
            {
                return false;
            }
        }
    }

    public class InnerNode : Node
    {
        internal Gee.List< Node > children = new Gee.LinkedList< Node >();

        public int children_count { get { return children.size; } }

        public bool add_child( Node child )
            requires( ( child in children ) == ( child.parent == this ) )
        {
            if( child.parent == null )
            {
                child.parent = this;
                children.add( child );
                return true;
            }
            else
            {
                return false;
            }
        }

        public bool remove_child( Node child )
        {
            return child.parent == this && child.remove_from_parent();
        }

        public void remove_all_children()
        {
            while( children.size > 0 ) remove_child( children.first() );
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

}

