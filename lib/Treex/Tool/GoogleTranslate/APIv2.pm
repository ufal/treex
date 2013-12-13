package Treex::Tool::GoogleTranslate::APIv2;
use Moose;
use Treex::Core::Common;
use utf8;

use LWP::UserAgent;
use URL::Encode;
use JSON;

has auth_token         => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has auth_token_in_file => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has tgt_lang           => ( is => 'rw', isa => 'Str',        default => 'en' );
has src_lang           => ( is => 'rw', isa => 'Maybe[Str]', default => undef ); # = autodetect

my $ua = LWP::UserAgent->new();

my $URL   = 'https://www.googleapis.com/language/translate/v2';
my $SL    = 'source'; # src lang param
my $TL    = 'target'; # tgt lang param
my $Q     = 'q';      # src text param
my $KEY   = 'key';    # authorization key param

sub BUILD {
    my ($self) = @_;

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

    return;
}

sub translate {
    my ( $self, $src_texts_array_ref, $params ) = @_;

    my $result = [];

    # process the parameters
    if ( !defined $src_texts_array_ref || @$src_texts_array_ref == 0 ) {
        log_warn 'Text for translation must be defined!';
        return $result;
    }
    if ( !defined $params ) {
        $params = {};
    }
    my $tgt_lang = $params->{tgt_lang} // $self->tgt_lang;
    my $src_lang = $params->{src_lang} // $self->src_lang;

    # build the query
    my $query = "$URL?$TL=$tgt_lang&$KEY=" . $self->auth_token;
    if ( defined $src_lang ) {
        $query .= "&$SL=$src_lang";
    }
    $query .= "&$Q=";
    $query .= join "&$Q=",
        ( map { URL::Encode::url_encode_utf8($_) } @$src_texts_array_ref );
    # TODO check query length to fit the 2K limit,
    # split into multiple requests if necessary

    # make the request
    # TODO: implement POST instead of GET to avoid length limit (2K characters)
    # log_info $query;
    my $response = $ua->get($query);

    # process the response
    if ( $response->is_success ) {

        # parse response into $result
        my $json = decode_json $response->decoded_content;
        my $translations = $json->{data}->{translations};
        foreach my $translation (@$translations) {
            push @$result, $translation->{translatedText};
        }

        # log_info "Translated $src_lang:'$src_text'" .
        #     " to $tgt_lang:'$translation'";
    }
    else {
        log_warn 'Translation did not succeed! Error: ' . $response->status_line;
    }

    return $result;
}

sub translate_simple {
    my ($self,
        $src_text,
        $tgt_lang, $src_lang
    ) = @_;

    my $result = $self->translate(
        [ $src_text ],
        { tgt_lang => $tgt_lang, src_lang => $src_lang }
    );
    my $translation = $result->[0] // '';
    return $translation;
}

sub translate_batch {
    my ($self,
        $src_texts_array_ref,
        $tgt_lang, $src_lang
    ) = @_;

    my $result = $self->translate(
        $src_texts_array_ref,
        { tgt_lang => $tgt_lang, src_lang => $src_lang }
    );
    return $result;
}

1;

=head1 NAME 

Treex::Tool::GoogleTranslate::APIv2

=head1 DESCRIPTION

Fetches a translation using Google Translate.

You need an API key, which is secret and therefore is not available in the SVN.
If you do not know it, contact me (rosa@ufal) and I will give it to you.

Uses the API documented here:
L<https://developers.google.com/translate/v2/getting_started>

The old API L<Treex::Tool::GoogleTranslate::APIv1> was shut down September 1st, 2013.
Please note that although the old API could return translation scores, alignment
information and nbest lists, the new one cannot do that (Google does not offer
that any more).

There is a limit of translating 100,000 characters per day.

Some parts of the API are not implemented, such as returning
detectedSourceLanguage.

=head1 SYNOPSIS

 use Treex::Tool::GoogleTranslate::APIv2;

 # if you have your Google auth_token in ~/.gta, it will be read from the file automatically
 my $translator1 = Treex::Tool::GoogleTranslate::APIv2->new();
 
 # or from another file that you specify
 my $translator2 = Treex::Tool::GoogleTranslate::APIv2->new(
    {auth_token_in_file => 'auth_token.txt' } );
 
 # otherwise, you must specify it in the constructor
 my $translator3 = Treex::Tool::GoogleTranslate::APIv2->new(
    {auth_token => 'D51f3D5d41...' } );
 

 # the default is to translate to en (source language is autodetected)
 my $translation1 = $translator1->translate_simple('ptakopysk');
 print $translation1;
 # prints 'platypus'

 # you can specify the translation direction in the query
 # the format is: translate_simple(query, to, from)
 my $translation2 = $translator1->translate_simple('ornitorinco', 'de', 'it');
 print $translation2;
 # prints 'Schnabeltier'

 # or you can specify the languages on creating the translator
 my $translator4 = Treex::Tool::GoogleTranslate::APIv2->new(
    { tgt_lang => 'sk', src_lang => 'es' });
 my $translation3 = $translator4->translate_simple('ornitorrinco');
 print $translation3;
 # prints 'vtákopysk'

 # you can also use batch translation, which makes only one request to the API
 # for all the texts and returns an array ref of translations
 my $translations4 = $translator1->translate_batch( ['ptakopysk', 'vznášedlo', 'úhoř']);
 print (join ' ', @$translations4);
 # prints 'platypus hovercraft eel'


=head1 PARAMETERS

=over

=item auth_token

Your UFAL API key from Google.
If you do not know it, contact me (rosa@ufal) and I will give it to you.
If not set, it will be attempted to read it from C<auth_token_in_file>.
If this is not successful, a C<log_fatal> will be issued.

=item auth_token_in_file

File containing the C<auth_token>.
Defaults to C<~/.gta> (cross-platform solution is used, i.e. C<~> is the user
home directory as returned by L<File::HomeDir>).

=item tgt_lang

Defaults to C<en>'.

See L<https://developers.google.com/translate/v2/using_rest#language-params> for supported languages.
(The Google API can also return the list of supported languages, but this
functionality is not implemented here.)

=item src_lang

Defaults to C<undef> for autodetect.

=head1 METHODS

Each of the methods can be called with one parameter only -
the text to be translated - in which case the values of the parameters are
used as they were set on the translator object (in the constructor or later).
Alternatively, the values of the parameters can be directly specified in the
method call, as described below.

However, the C<auth_token> must be specified in the constructor (or read from
C<auth_token_in_file>) and cannot be changed later.

=over

=item $translator->translate(src_texts_array_ref, params)

Translate C<src_texts_array_ref> (a reference to an array of strings)
to C<tgt_lang> from C<src_lang>.
The parameters can be overriden by setting them in the C<params> hash ref.

Returns a reference to an array containing the translations
(to an empty array if translations are not available).

=back

Two overrides with simpler API are provided:

=item translate_simple(src_text, ?tgt_lang, ?src_lang)

Returns a string - the translation of C<src_text>.
(The string may be empty.)

=item translate_batch(src_texts_array_ref, ?tgt_lang, ?src_lang)

Returns an array reference - the translations of texts in C<src_texts_array_ref>.
(The array may be empty.)

Please note that there is a limit of 2K characters for the length of the
translation request.
(This block does neither check that nor split the translations into multiple
requests -- this is only a TODO now.)

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

