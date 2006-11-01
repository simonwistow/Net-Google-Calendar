package Net::Google::Calendar;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use XML::Atom::Feed;
use XML::Atom::Entry;
use Data::Dumper;
use Net::Google::Calendar::Entry;
use Net::Google::Calendar::Person;
use URI;
use URI::Escape;

use vars qw($VERSION $APP_NAME);

$VERSION  = "0.5";
$APP_NAME = __PACKAGE__."-${VERSION}"; 

=head1 NAME

Net::Google::Calendar - programmatic access to Google's Calendar API


=head1 SYNOPSIS

    my $cal = Net::Google::Calendar->new( url => $url );
    $cal->login($u, $p);


    for ($cal->get_events()) {
        print $_->title."\n";
        print $_->content->body."\n*****\n\n";
    }

    my $entry = Net::Google::Calendar::Entry->new();
    $entry->title($title);
    $entry->content("My content");
    $entry->location('London, England');
    $entry->transparency('transparent');
    $entry->status('confirmed');
    $entry->when(DateTime->now, DateTime->now() + DateTime::Duration->new( hours => 6 ) );


    my $author = Net::Google::Calendar::Person->new();
    $author->name('Foo Bar');
    $author->email('foo@bar.com');
    $entry->author($author);

    my $tmp = $cal->add_entry($entry);
    die "Couldn't add event: $@\n" unless defined $tmp;

    print "Events=".scalar($cal->get_events())."\n";

    $tmp->content('Updated');

    $cal->update_entry($tmp) || die "Couldn't update ".$tmp->id.": $@\n";

    $cal->delete_entry($tmp) || die "Couldn't delete ".$tmp->id.": $@\n";



=head1 DESCRIPTION

Interact with Google's new calendar.

=head1 METHODS

=cut

=head2 new <opts>

Create a new instance. opts is a hash which must contain your private Google url.

See 

    http://code.google.com/apis/gdata/calendar.html#find_feed_url

for how to get that.

=cut

sub new {
    my ($class, %opts) = @_;
    $opts{_ua} = LWP::UserAgent->new;    
    ($opts{calendar_id}) = ($opts{url} =~ m!/feeds/([^/]+)/!);

    return bless \%opts, $class;

}


=head2 login <username> <password>

Login to google.

=cut

sub login {
    my ($self, $user, $pass) = @_;
    # send auth request
    my $r = $self->{_ua}->request(POST 'https://www.google.com/accounts/ClientLogin', [ Email => $user, Passwd => $pass, service => 'cl', source => $APP_NAME ]);
    unless ($r->is_success) { $@ = $r->status_line; return undef; }
    my $c = $r->content;
    my ($auth) = $c =~ m!Auth=(.+)(\s+|$)!; 
    unless (defined $auth) {
        $@ = "Couldn't extract auth token from '$c'";
        return undef; 
    }
    # store auth token
    $self->{_auth} = $auth;
    $self->{user}  = $user;
    $self->{pass}  = $pass; 
    return 1;
}

=head2 get_events [ %opts ]

Return a list of Net::Google::Calendar::Entry objects;

You can pass in a hash of options which map to the Google Data API's generic 
searching mechanisms plus the specific calendar ones.

See

    http://code.google.com/apis/gdata/protocol.html#query-requests

for more details.


=over 4

=item q

Full-text query string

When creating a query, list search terms separated by spaces, in the
form q=term1 term2 term3. (As with all of the query parameter values,
the spaces must be URL encoded.) The GData service returns all entries
that match all of the search terms (like using AND between terms). Like
Google's web search, a GData service searches on complete words (and
related words with the same stem), not substrings.

To search for an exact phrase, enclose the phrase in quotation marks: 

    q => '"exact phrase'

To exclude entries that match a given term, use the form 

    q => '-term'

The search is case-insensitive.

Example: to search for all entries that contain the exact phrase
'Elizabeth Bennet' and the word 'Darcy' but don't contain the word
'Austen', use the following query: 

    q => '"Elizabeth Bennet" Darcy -Austen'


=item category

Category filter

To search in just one category do

    category => 'Fritz'    

You can query on multiple categories by listing multiple category parameters. For example

    category => [ 'Fritz', 'Laurie' ]

returns entries that match both categories.


To do an OR between terms, use a pipe character (|). For example


    category => 'Fritz|Laurie'

returns entries that match either category.

To exclude entries that match a given category, use the form 

    category => '-categoryname'

You can, of course, mix and match

    [ 'Jo', 'Fritz|Laurie', '-Simon' ]

means in category 

    (Jo AND ( Fritz OR Laurie ) AND (NOT Simon)) 


=item author

Entry author

The service returns entries where the author name and/or email address 
match your query string.

=item updated-min

=item updated-max

Bounds on the entry publication date.

Use DateTime objects or the RFC 3339 timestamp format. For example:
2005-08-09T10:57:00-08:00.

The lower bound is inclusive, whereas the upper bound is exclusive.

=item start-min

=item start-max

Respectively, the earliest event start time to match (If not specified, 
default is 1970-01-01) and the latest event start time to match (If 
not specified, default is 2031-01-01).

Use DateTime objects or the RFC 3339 timestamp format. For example:
2005-08-09T10:57:00-08:00.

The lower bound is inclusive, whereas the upper bound is exclusive.

=item start-index

1-based index of the first result to be retrieved

Note that this isn't a general cursoring mechanism. If you first send a 
query with 

    start-index => 1,
    max-results => 10 

and then send another query with

    start-index => 11,
    max-results => 10

the service cannot guarantee that the results are equivalent to
    
    start-index => 1
    max-results => 20

because insertions and deletions could have taken place in between the
two queries.

=item max-results

Maximum number of results to be retrieved.

For any service that has a default max-results value (to limit default 
feed size), you can specify a very large number if you want to receive 
the entire feed.

=item entryID

ID of a specific entry to be retrieved.

If you specify an entry ID, you can't specify any other parameters.

=back

=cut

sub get_events {
    my ($self, %opts) = @_;


    # check for DateTime objects and convert them to RFC 3339 
    for (keys %opts) {
        next unless UNIVERSAL::isa($opts{$_}, 'DateTime');
        # maybe we should chuck an error if it's a Ref and *not* a DateTime
        #next unless $opts{$_}->isa('DateTime');
        $opts{$_} = $opts{$_}->iso8601 . 'Z';
    }

    my $url = URI->new($self->{url});

    if (exists $opts{entryID}) {
        if (scalar(keys %opts)>1) {
            $@ = "You can't specify entryID and anything else";
            return undef;    
        }
        my $path = $url->path;
        $url->path("$path/".$opts{entryID});
    }

    if (exists $opts{category} && 'ARRAY' eq ref($opts{category})) {
        my $path = $url->path."/".join("/", ( '-', @{delete $opts{category}}));
        $url->path("$path");
    }

    $url->query_form(\%opts);

    my %params;
    %params = ( Authorization => "GoogleLogin auth=".$self->{_auth} ) if (defined $self->{_auth});
    my $r   = $self->{_ua}->get("$url", %params);
    die $r->status_line unless $r->is_success;
    my $atom = $r->content;

    my $feed = XML::Atom::Feed->new(\$atom);
    return map {  bless $_, 'Net::Google::Calendar::Entry'; $_->_initialize(); $_ } $feed->entries;
}


=head2 get_calendars

Get a list of user's Calendars as Net::Google::Calendar::Entry objects.

=cut

sub get_calendars {
    my $self = shift;
    my $url = URI->new("http://www.google.com/calendar/feeds/".$self->{user});

    my %params;
    %params = ( Authorization => "GoogleLogin auth=".$self->{_auth} ) if (defined $self->{_auth});
    my $r   = $self->{_ua}->get("$url", %params);
    die $r->status_line unless $r->is_success;
    my $atom = $r->content;

    my $feed = XML::Atom::Feed->new(\$atom);
    # TODO maybe these should be Net::Google::Calendar::Entry::Calendar objects or something
    return map {  bless $_, 'Net::Google::Calendar::Entry'; $_->_initialize(); $_ } $feed->entries;
}

=head2 set_calendar <Net::Google::Calendar::Entry>

Set the current calendar to use.

=cut

sub set_calendar {
    my $self = shift;
    my $cal  = shift;

    ($self->{calendar_id}) = (uri_unescape($cal->id) =~ m!([^/]+)$!);
    $self->{url} =  "http://www.google.com/calendar/feeds/$self->{calendar_id}/private/full";
}



=head2 add_entry <Net::Google::Calendar::Entry>

Create a new entry.

=cut

sub add_entry {
    my ($self, $entry) = @_;

    # TODO for neatness' sake we could make calendar_id = 'default' when calendar_id = user
    my $url =  "http://www.google.com/calendar/feeds/$self->{calendar_id}/private/full"; 
    return $self->_do($entry, $url, 'POST');

}


=head2 delete_entry <Net::Google::Calendar::Entry>

Delete a given entry.

=cut

sub delete_entry {
    my ($self, $entry) = @_;
    my $url = $entry->edit_url || return undef;
    return $self->_do($entry, $url, 'DELETE');

}

=head2 update_entry <Net::Google::Calendar::Entry>

Update a given entry.

=cut

sub update_entry {
    my ($self, $entry) = @_;
    my $url = $entry->edit_url || return undef;
    return $self->_do($entry, $url, 'PUT');

}

sub _do {
    my ($self, $entry, $url, $method) = @_;

    unless (defined $self->{_auth}) {
        $@ = "You must log in to do a $method\n";
        return undef;
    }

    if (defined $self->{_session_id} && !$self->{_force_no_session_id}) {
        my $tmp = URI->new($url);
        $tmp->query_form({ gsessionid => $self->{_session_id} });
        $url = "$tmp";
    }

    my $xml = $entry->as_xml;
    _utf8_off($xml);
    my %params = ( Content_Type => 'application/atom+xml; charset=UTF-8',
                   Authorization => "GoogleLogin auth=".$self->{_auth},
                   Content => $xml );

    $params{'X-HTTP-Method-Override'} = $method unless "POST" eq $method;
    

    while (1) {
        my $rq = POST $url, %params;
        my $r = $self->{_ua}->request( $rq );

        if (302 == $r->code) {
            $url = $r->header('location');
            my %args = URI->new($url)->query_form;
            $self->{_session_id} = $args{gsessionid};
            next;
        }

        if (!$r->is_success) {
            $@ = $r->status_line." - ".$r->content;
            return undef;
        }
        my $c = $r->content;
        if (defined $c && length($c)) {
            return Net::Google::Calendar::Entry->new(Stream => \$c);
        } else {
            # in the case of DELETE should we return 1 instead?
            return $entry;
        }
    }


}

sub _utf8_off {
    if ($] >= 5.008) {
        require Encode;
        return Encode::_utf8_off($_[0]);
    }
}

=head1 WARNING

This is ALPHA level software. 

Don't use it. Ever. Or something.

=head1 TODO

Abstract this out to Net::Google::Data

=head1 LATEST VERSION

The latest version can always be obtained from my 
Subversion repository.

    http://unixbeard.net/svn/simon/Net-Google-Calendar

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYRIGHT

Copyright Simon Wistow, 2006

Distributed under the same terms as Perl itself.

=head1 SEE ALSO

http://code.google.com/apis/gdata/calendar.html

=cut

1;
