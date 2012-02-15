package Treex::Tool::Tagger::Featurama::CS;
use Moose;
extends 'Treex::Tool::Tagger::Featurama';

use CzechMorpho;
use List::Util qw(first);

has _analyzer => (
    is       => 'ro',
    isa      => 'CzechMorpho::Analyzer',
    builder  => '_build_analyzer',
    lazy     => 1,
    init_arg => undef,
);

sub BUILDARGS {
    return { path => 'data/models/tagger/featurama/cs/default' };
}

# TODO: make this more portable, e.g. requiring all the files from share
sub _build_analyzer {
    my $self = shift;
    return CzechMorpho::Analyzer->new($ENV{TMT_ROOT}.'/share/data/models/morpho_analysis/cs_060406a');
}

override '_analyze' => sub {
    my ( $self, $wordform ) = @_;
    my @analyses;

    foreach ( $self->_analyzer->analyze($wordform) ) {
        my $analysis_rf = {};
        $analysis_rf->{'lemma'} = $_->{'lemma'};
        $analysis_rf->{'tag'}   = $_->{'tag'};
        push( @analyses, $analysis_rf );
    }
    return @analyses;
};

override '_get_feature_names' => sub {
    return qw(Form Prefix1 Prefix2 Prefix3 Prefix4 Suffix1 Suffix2 Suffix3 Suffix4
        Num Cap Dash FollowingVerbTag FollowingVerbLemma Tag);
};

override '_get_features' => sub {

    my ( $self, $forms, $analyses, $index ) = @_;
    my $wordform = $forms->[$index];
    my $analysis = $analyses->[$index];

    my @features;

    #Form
    push( @features, $wordform );

    #Prefixes
    push( @features, substr( $wordform, 0, 1 ) );
    push( @features, substr( $wordform, 0, 2 ) );
    push( @features, substr( $wordform, 0, 3 ) );
    push( @features, substr( $wordform, 0, 4 ) );

    #Suffixes
    push( @features, substr( $wordform, -1, 1 ) );
    push( @features, substr( $wordform, -2, 2 ) );
    push( @features, substr( $wordform, -3, 3 ) );
    push( @features, substr( $wordform, -4, 4 ) );

    #Num
    push( @features, $wordform =~ /[0-9]/ ? 1 : 0 );

    #Cap
    push( @features, $wordform =~ /[[:upper:]]/ ? 1 : 0 );

    #Dash
    push( @features, $wordform =~ /[–—-]/ ? 1 : 0 );

    # FollowingVerbTag + FollowingVerbLemma
    push( @features, $self->_find_following_verb( $analyses, $index ) );

    # Tag
    push( @features, "NULL" );

    # Analyses (add lemmas as "additional tags")
    push @features, map { $_->{tag} . ' ' . $_->{lemma} } @{$analysis};
    return @features;
};

override '_extract_tag_and_lemma' => sub {
    my ( $self, $index, $wordform ) = @_;
    
    return {
        tag => $self->perc->getProposedTag( $index, 0 ),
        lemma => $self->perc->getAdditionalProposedTag( $index, 0 )
    };
};

# Returns the lemma + tag of the first following verb
sub _find_following_verb {

    my ( $self, $analyses, $i ) = @_;
    for ( ; $i < @{$analyses}; ++$i ) {
        my $analysis = $analyses->[$i];
        my $verb = first { $_->{tag} =~ /^V/ } @{$analysis};    # if there are multiple analyses, try the first one
        return ( $verb->{tag}, $verb->{lemma} ) if ($verb);
    }

    # no possible verb till the end of the sentence
    return ( 'NULL', 'NULL' );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Tagger::Featurama::CS

=head1 VERSION

=head1 DESCRIPTION

Featurama feature set and analysis for Czech

=head2 OVERRIDEN METHODS

=over

=item _analyze($wordform)

Uses CzechMorpho::Analyzer->analyze()

=item _get_feature_names()

Returns feature names for Czech

=item _get_features($wordforms_rf, $analyses_rf_rf, $index)

Returns features for Czech

=item _extract_tag_and_lemma($index, $wordform)

Returns proposed tag and wordform

=back

=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
