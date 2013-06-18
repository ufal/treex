package Treex::Tool::GoogleTranslate::APIv1;
use Moose;
use Treex::Core::Common;
use utf8;

use LWP::UserAgent;
use URL::Encode;
use XML::Simple;

has auth_token         => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has auth_token_in_file => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has src_lang           => ( is => 'rw', isa => 'Str',        default => 'cs' );
has tgt_lang           => ( is => 'rw', isa => 'Str',        default => 'en' );
has align              => ( is => 'rw', isa => 'Bool',       default => 0 );
has nbest              => ( is => 'rw', isa => 'Num',        default => 0 );

has ua => ( is => 'rw', isa => 'LWP::UserAgent' );

my $URL   = 'http://translate.google.com/researchapi/translate';
my $ALIGN = 'align';                                               # output alignment param
my $NBEST = 'nbest';                                               # output n-best param
my $SL    = 'sl';                                                  # src lang param
my $TL    = 'tl';                                                  # tgt lang param
my $Q     = 'q';                                                   # src text param

sub BUILD {
    my ($self) = @_;

    $self->set_ua( LWP::UserAgent->new() );

    # auth_token
    if ( !defined $self->auth_token ) {

        # try to find it in file
        if ( !defined $self->auth_token_in_file ) {
            use File::HomeDir;
            $self->set_auth_token_in_file( File::HomeDir->my_home . "/.gta" );
        }

        open my $file, '<:utf8', $self->auth_token_in_file
            or log_fatal 'Cannot find Google Translate auth_token in file "' .
            $self->auth_token_in_file .
            '"! You must provide your auth_token for the translation to work.';
        my $auth_token = <$file>;
        chomp $auth_token;
        $self->set_auth_token($auth_token);
    }
    $self->ua->default_header( 'Authorization' => 'GoogleLogin auth=' . $self->auth_token );

    return;
}

sub translate {
    my ( $self, $src_text, $params ) = @_;

    my $result = {
        translation  => '',
        translations => [],
        align        => []
    };

    # make the query
    if ( !defined $src_text ) {
        log_warn 'Text for translation must be defined!';
        return $result;
    }
    if ( !defined $params ) {
        $params = {};
    }
    my $src_lang = $params->{src_lang} // $self->src_lang;
    my $tgt_lang = $params->{tgt_lang} // $self->tgt_lang;
    my $nbest    = $params->{nbest}    // $self->nbest;
    my $align    = $params->{align}    // $self->align;
    my $src_text_encoded = URL::Encode::url_encode_utf8($src_text);

    my $query = "$URL?$SL=$src_lang&$TL=$tgt_lang&$Q=$src_text_encoded";
    if ($align) {
        $query .= "&$ALIGN";
    } elsif ($nbest) {
        $query .= "&$NBEST=$nbest";
    }

    # make the request
    my $response = $self->ua->get($query);

    # process the response
    if ( $response->is_success ) {

        # parse response into $result
        my $xml = XML::Simple::XMLin( $response->decoded_content );

        my $entry = $xml->{'entry'};
        if ( ref($entry) eq 'HASH' ) {

            # single-best

            # translation
            my $translation = $entry->{'gt:translation'}->{'content'};
            my $score = $entry->{'gt:feature'}->{'score'} // 0;
            $result->{translation} = $translation;
            push @{ $result->{translations} }, {
                translation => $translation,
                score       => $score,
            };

            # align
            my $align = $xml->{'entry'}->{'gt:alignment'};
            if ( defined $align ) {
                if ( ref($align) eq 'ARRAY' ) {
                    $result->{align} = $align;
                }
                elsif ( ref($align) eq 'HASH' ) {
                    push @{ $result->{align} }, $align;
                }
                else {
                    log_warn "Unexpected value of align: $align";
                }
            }
        }
        elsif ( ref($entry) eq 'ARRAY' ) {

            # n-best
            foreach my $subentry (@$entry) {

                # translation
                my $translation = $subentry->{'gt:translation'}->{'content'};
                my $score = $subentry->{'gt:feature'}->{'score'} // 0;
                push @{ $result->{translations} }, {
                    translation => $translation,
                    score       => $score,
                };
            }
            $result->{translation} = $result->{translations}->[0]->{translation};
        }
        else {
            log_warn "Cannot parse entry $entry!";
        }
    }
    else {
        log_warn 'Translation did not succeed! Error: ' . $response->status_line;
    }

    return $result;
}

sub translate_simple {
    my ($self,
        $src_text,
        $src_lang, $tgt_lang
    ) = @_;

    my $result = $self->translate(
        $src_text,
        { src_lang => $src_lang, tgt_lang => $tgt_lang, nbest => 0, align => 0 }
    );
    return $result->{translation};
}

sub translate_align {
    my ($self,
        $src_text,
        $src_lang, $tgt_lang
    ) = @_;

    my $result = $self->translate(
        $src_text,
        { src_lang => $src_lang, tgt_lang => $tgt_lang, nbest => 0, align => 1 }
    );
    delete $result->{translations};
    return $result;
}

sub translate_nbest {
    my ($self,
        $src_text, $nbest,
        $src_lang, $tgt_lang
    ) = @_;

    my $result = $self->translate(
        $src_text,
        { src_lang => $src_lang, tgt_lang => $tgt_lang, nbest => $nbest, align => 0 }
    );
    return $result->{translations};
}

1;

=head1 NAME 

Treex::Tool::GoogleTranslate::APIv1

=head1 DESCRIPTION

Fetches a translation using Google Translate.
Requires a Google API C<auth_token>.

Uses the API documented here:
L<http://research.google.com/university/translate/docs.html>

The API has been deprecated and will be shut down September 1st, 2013. 

There are some limits, probably 1000 requests per day and 1000 characters per
request (I have to test that to know it exactly).

B<Currently, requesting n best translations does not work! (For unknown reason.)>

=head1 SYNOPSIS

 use Treex::Tool::GoogleTranslate::APIv1;

 # if you have your Google auth_token in ~/.gta, it will be read from the file automatically
 my $translator1 = Treex::Tool::GoogleTranslate::APIv1->new();
 
 # or from another file that you specify
 my $translator2 = Treex::Tool::GoogleTranslate::APIv1->new(
    {auth_token_in_file => 'auth_token.txt' } );
 
 # otherwise, you must specify it in the constructor
 my $translator3 = Treex::Tool::GoogleTranslate::APIv1->new(
    {auth_token => 'D51f3D5d41...' } );
 

 # the default is to translate from cs to en
 my $translation1 = $translator1->translate_simple('ptakopysk');
 print $translation1;
 # prints 'platypus'

 # you can specify the translation direction in the query
 my $translation2 = $translator1->translate_simple('ornitorinco', 'it', 'de');
 print $translation2;
 # prints 'Schnabeltier'

 # or you can specify the languages on creating the translator
 my $translator4 = Treex::Tool::GoogleTranslate::APIv1->new(
    { src_lang => 'es', tgt_lang => 'sk' });
 my $translation3 = $translator4->translate_simple('ornitorrinco');
 print $translation3;
 # prints 'vtákopysk'


 # TODO: align
 
 # TODO: nbest

=head1 PARAMETERS

=over

=item auth_token

Your AUTH_TOKEN from Google.
If not set, it will be attempted to read it from C<auth_token_in_file>.
If this is not successful, a C<log_fatal> will be issued.

If you have registered for the University Research
Program for Google Translate, you can get one using your email, password and the
following procedure (copied from official manual):

Here is an example using curl to get an authentication token:

  curl -d "Email=username@domain&Passwd=password&service=rs2" https://www.google.com/accounts/ClientLogin

Make sure you remember to substitute in your username@domain and password. Also, be warned that your username and password may be stored in your history file (e.g., .bash_history) and you should take precautions to remove it when finished. 

=item auth_token_in_file

File containing the C<auth_token>.
Defaults to C<~/.gta> (cross-platform solution is used, i.e. C<~> is the user
home directory as returned by L<File::HomeDir>).

=item src_lang

Defaults to 'cs'.

=item tgt_lang

Defaults to 'en'.

=item align

1 to get alignment information. Defaults to 0.

=item nbest

Number of n-best translations to return. Defaults to 0, which effectively means
1-best, but the request to Google API is different if nbest is set to 1.
The Google Translate API has a maximum of 25 n-best translations.

B<Currently, requesting n best translations does not work! (For unknown reason.)>

=back

Please note that C<align> and C<nbest> are mutually exclusive. C<align> has higher priority, so
if you request both, you will get C<align> but you will not get C<nbest>.

=head1 METHODS

Each of the methods can be called with one parameter only - the C<src_text>,
ie. the text to be translated - in which case the values of the parameters are
used as they were set on the translator object (in the constructor or later).
Alternatively, the values of the parameters can be directly specified in the
method call, as described below.

However, the C<auth_token> must be specified in the constructor (or read from
C<auth_token_in_file>) and cannot be changed later.

=over

=item $translator->translate(src_text, params)

Translate C<src_text> from C<src_lang> to C<tgt_lang>, returning C<nbest>
translations or C<align> information if requested.
The parameters can be overriden by setting them in the C<params> hash ref.

B<Currently, requesting n best translations does not work! (For unknown reason.)>

Returns a hash ref with the following structure:

=over

=item translation

A string with the translation.

=item translations

An array ref of hash refs of nbest translations, ordered from best to worst.
Only the 1 best if nbest not requested. May
contain less translations than requested as Google Translate does not always
generate that many translations.

Each item has 2 keys:

=over

=item translation

The translation (string).

=item score

Lower is better. The C<score> may be 0, which means that it was not provided -- Google
Translate only provides the score with nbest requests.

=back

=item align

An array ref of hash refs on alignment information, or empty array ref if align info not requested.

Each item has 2 keys:

=over

=item word

A string containing a target word.

=item position

A 0-based character-wise position in the source sentence.

=back

=back

=item translate_simple(src_text, ?src_lang, ?tgt_lang)

Returns a string - the translation of C<src_text>.

=item translate_align(src_text, ?src_lang, ?tgt_lang)

Returns a hash ref with C<translation> and C<align> (see C<translate>).

=item translate_nbest(src_text, ?nbest, ?src_lang, ?tgt_lang)

Returns an array ref of at most C<nbest> hash refs of translations, each containing
C<translation> and C<score> (see C<translate>).

B<Currently, requesting n best translations does not work! (For unknown reason.)>

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

