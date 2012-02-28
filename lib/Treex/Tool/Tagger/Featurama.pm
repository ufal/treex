package Treex::Tool::Tagger::Featurama;
use Moose;
use Moose::Exporter;

Moose::Exporter->setup_import_methods(
    as_is => ['tag_sentence'],
);

use Treex::Core::Resource qw(require_file_from_share);
use Treex::Core::Common;
has path => (
    is            => 'ro',
    isa           => 'Str',               #or isa=> 'Path' ?
    required      => 1,
    documentation => q{Path to models},
);

has perc => (
    is            => 'ro',
    isa           => 'Featurama::Perc',
    builder       => '_build_perc',
    lazy          => 1,
    init_arg      => undef,
    predicate     => '_perc_built',
    documentation => q{Wrapped C object},
);

sub _build_perc {
    my $self   = shift;
    my $path   = $self->path;
    eval {    
        require Featurama::Perc;    #when featurama will be on CPAN, it will be probably in different namespace
        1;
    } or log_fatal('Cannot load Featurama::Perc. Please check whether it is installed');
    my $perc   = Featurama::Perc->new();
    my $header = join "\t", $self->_get_feature_names();
    my $f      = require_file_from_share( $self->path . '.f' );
    my $dict   = require_file_from_share( $self->path . '.dict' );
    my $alpha  = require_file_from_share( $self->path . '.alpha' );
    if ( not $perc->testInit( $f, $dict, $alpha, $header, 0, 1, 3 ) ) {    # TODO zjistit, co ty cislicka znamenaji
        log_fatal("Cannot initialize Featurama::Perc");
    }
    return $perc;
}

sub DEMOLISH {
    my $self = shift;
    if ( $self->_perc_built ) {
        $self->perc->testFinish();
    }
}

sub tag_sentence {
    my ( $self, $wordforms_rf, $analyses_rf ) = @_;
    my $count = scalar @{$wordforms_rf};

    if ( !$analyses_rf ) {

        # array of analyses, each analysis is an array of lemma/tag info stored in a hash
        my @temp = @{$wordforms_rf};
        my @analyses = map { [ $self->_analyze($_) ] } @temp;

        $analyses_rf = \@analyses;
    }

    # tagging
    my ( $tags_rf, $lemmas_rf ) = $self->_tag( $wordforms_rf, $analyses_rf );

    return ( $tags_rf, $lemmas_rf );
}

sub _get_feature_names {
    log_fatal( 'This method has to be overriden: ' . ( caller(0) )[3] );
}

sub _get_features {
    log_fatal( 'This method has to be overriden: ' . ( caller(0) )[3] );
}

sub _extract_tag_and_lemma {
    log_fatal( 'This method has to be overriden: ' . ( caller(0) )[3] );
}

sub _analyze {
    log_fatal( 'This method has to be overriden: ' . ( caller(0) )[3] );
}

sub _tag {
    my ( $self, $forms, $analyses ) = @_;

    my @sent;

    # extract features
    foreach my $i ( 0 .. $#{$forms} ) {    #go through word forms and analyses
    
        my @word = $self->_get_features( $forms, $analyses, $i );    #load features
        push( @sent, \@word );
    }

    $self->perc->beginSentence();
    foreach my $word_rf (@sent) {
        $self->perc->appendWord( join( "\t", @{$word_rf} ) );
    }
    $self->perc->endSentence();

    my ( @tags, @lemmas );
    foreach my $i ( 0 .. $#{$forms} ) {
        my $tag_and_lemma = $self->_extract_tag_and_lemma( $i, $forms->[$i] );
        push( @tags,   $tag_and_lemma->{tag} );
        push( @lemmas, $tag_and_lemma->{lemma} );
    }

    return ( \@tags, \@lemmas );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Tagger::Featurama

=head1 DESCRIPTION

Perl wrapper for Featurama implementation of Collins' perceptron algorithm.

=head1 SYNOPSIS

 use Treex::Tool::Tagger::Featurama;

 my @wordforms = qw(John loves Jack);

 my $tagger = Treex::Tool::Tagger::Featurama->new(path => '/path/to/model');

 my ($tags_rf, $lemmas_rf) = $tagger->tag_sentence(\@wordforms);

=head2 CONSTRUCTOR

=over

=item  my $tagger = Treex::Tool::Tagger::Featurama->new(path = '/path/to/model');

=back

=head2 METHODS

=over

=item  my ($tags_rf) = $tagger->tag_sentence(\@wordforms);

=back

=head2 METHODS TO OVERRIDE

=over

=item _analyze($wordform)

This method should provide all possible morphological analyses for the given wordform.

=item _get_feature_names()

This method should return an array of feature names.

=item _get_features($wordforms_rf, $analyses_rf_rf, $index)

This method should return an array of features, given 
all wordforms in the sentence,
all possible morphological analyses for each of the wordforms,
and a position in the sentence.
Since the features may include parts of the context, it is necessary to provide the whole
sentence to this function.
For example:

 $featurama->_get_features(
     [qw(Time flies)],
     [[qw(NN NNP VB JJ)], [qw(VBZ NNS)]],
     0
 );

=item _extract_tag_and_lemma($index, $wordform)

This method should extract tag and lemma given index in sentence and wordform.
It will probably want to use $self->perc
TODO this will probably change

=back

=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

