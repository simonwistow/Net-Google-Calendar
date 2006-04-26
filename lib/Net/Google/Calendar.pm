package Net::Google::Calendar;

use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use XML::Atom::Feed;
use XML::Atom::Entry;
use Data::Dumper;
use Net::Google::Calendar::Entry;
use Net::Google::Calendar::Person;

use vars qw($VERSION $APP_NAME);

$VERSION  = "0.1_devel";
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


    my $author = Net::Google::Calendar::Person->new( Version => '1.0' );
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
    # store auth token
    $self->{_auth} = $auth;
    $self->{user}  = $user;
    $self->{pass}  = $pass; 
    return 1;
}

=head2 get_events

Return a list of Net::Google::Calendar::Entry objects;

=cut

sub get_events {
    my ($self, %opts) = @_;
    my $r = $self->{_ua}->get($self->{url}, Authorization => "GoogleLogin auth=".$self->{_auth});
    die $r->status_line unless $r->is_success;
    my $atom = $r->content;

    my $feed = XML::Atom::Feed->new(\$atom);
    return map {  bless $_, 'Net::Google::Calendar::Entry' } $feed->entries;
}


=head2 add_entry <Net::Google::Calendar::Entry>

Create a new entry.

=cut

sub add_entry {
    my ($self, $entry) = @_;

    my $url = 'http://www.google.com/calendar/feeds/default/private/full'; 
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

    if (defined $self->{_session_id} && !$self->{_force_no_session_id}) {
        if ($url =~ m!\?!) {
            $url .= "&";
        } else {
            $url .= "?";
        }
        $url .= "gsessionid=".$self->{_session_id};
    }

    my %params = ( Content_Type => 'application/atom+xml',
                   Authorization => "GoogleLogin auth=".$self->{_auth},
                   Content => $entry->as_xml );

    $params{'X-HTTP-Method-Override'} = $method unless "POST" eq $method;
    

    while (1) {
        my $rq = POST $url, %params;
        my $r = $self->{_ua}->request( $rq );

        if (302 == $r->code) {
            $url = $r->header('location');
            ($self->{_session_id}) = $url =~ m![?&]gsessionid=(.+)$!;
            next;
        }

        if (!$r->is_success) {
            $@ = $r->status_line;
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


=head1 WARNING

This is ALPHA level software. 

Don't use it. Ever. Or something.

=head1 TODO

Abstract this out to Net::Google::Data

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYRIGHT

Copyright Simon Wistow, 2006

Distributed under the same terms as Perl itself.

=head1 SEE ALSO

http://code.google.com/apis/gdata/calendar.html

=cut

1;
