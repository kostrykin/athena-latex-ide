namespace SourceStructure
{

    public enum Feature { LABEL, BIB_ENTRY }

    public class Node
    {
        public weak InnerNode? parent { public get; protected set; default = null; }
        public Gee.Map< Feature, string > features { public get; private set; default = new Gee.HashMap< Feature, string >(); }

        public delegate bool Visitor( Node node );
        public virtual bool search_feature( Feature feature, Visitor visit )
        {
            if( feature in features.keys )
            {
                if( !visit( this ) ) return false;
            }
            return true;
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

        public override bool search_feature( Feature feature, Node.Visitor visit )
        {
            if( !base.search_feature( feature, visit ) ) return false;
            foreach( var child in children )
            {
                if( !child.search_feature( feature, visit ) ) return false;
            }
            return true;
        }
    }

}

