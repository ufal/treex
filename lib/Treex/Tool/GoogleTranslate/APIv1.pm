package Treex::Tool::GoogleTranslate::APIv1;
use Moose;
use Treex::Core::Common;
use utf8;

use LWP::UserAgent;
use URL::Encode;
use XML::Simple;

has auth_token => ( is => 'rw', isa => 'Str', default => undef );
has src_lang => ( is => 'rw', isa => 'Str', default => 'cs' );
has tgt_lang => ( is => 'rw', isa => 'Str', default => 'en' );
has align => ( is => 'rw', isa => 'Bool', default => 0 );
#has nbest => ( is => 'rw', isa => 'Num', default => 1 );

my $URL='http://translate.google.com/researchapi/translate';
my $ALIGN='align'; # output alignment param
my $SL='sl'; # src lang param
my $TL='tl'; # tgt lang param
my $Q='q';   # src text param

my $ua;

sub BUILD {
    my ($self) = @_;

    $ua = LWP::UserAgent->new();
    my $auth_token = $self->auth_token;
    if ( !defined $auth_token ) {
        log_warn 'auth_token must be specified!';
    }
    $ua->default_header('Authorization' => "GoogleLogin auth=$auth_token");

    return ;
}

sub translate {
    my ($self,
        $src_text,
        $src_lang, $tgt_lang,
        $align, #$nbest
    ) = @_;

    my $src_text_encoded = URL::Encode::url_encode_utf8($src_text);

    my $query="$URL?$ALIGN&$SL=$src_lang&$TL=$tgt_lang&$Q=$src_text_encoded";

    my $response = $ua->get($query);

    if ($response->is_success) {
        #print $response->decoded_content;  # or whatever
        my $xml = XML::Simple::XMLin($response->decoded_content);
        #say keys %{$xml->{'entry'}->{'gt:translation'}};
        # TODO: handle alignment, nbest
        return $xml->{'entry'}->{'gt:translation'}->{'content'};
    }
    else {
        log_warn $response->status_line;
        return undef;
    }
}

1;

=head1 NAME 

Treex::Tool:GoogleTranslate

=head1 DESCRIPTION

Fetches a translation using Google Translate.
Requires a Google API auth token.

=head1 PARAMETERS

=over

=item auth_token

=item src_lang

=item tgt_lang

=item align

#=item nbest

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

