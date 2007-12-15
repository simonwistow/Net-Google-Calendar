package Net::Google::Calendar::Base;

use XML::Atom::Thing;
use XML::Atom::Util qw( set_ns first nodelist childlist iso2dt);

# work round get in XML::Atom::Thing which stringifies stuff
sub _my_get {
    my $obj = shift;
    my($ns, $name) = @_;
    my @list = $obj->_my_getlist($ns, $name);
    return $list[0];
}

sub _my_getlist {
    my $obj = shift;
    my($ns, $name) = @_;
    my $ns_uri = ref($ns) eq 'XML::Atom::Namespace' ? $ns->{uri} : $ns;
    my @node = childlist($obj->elem, $ns_uri, $name);
    return @node;
}

1;
