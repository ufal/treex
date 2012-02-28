package Treex::Tool::Tagger::Featurama::CS;
use Moose;
extends 'Treex::Tool::Tagger::Featurama';

use CzechMorpho;
use List::Util qw(first);
use Readonly;
use Treex::Core::Resource qw(require_file_from_share);

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


has analyzer_version => ( is => 'ro', isa => 'Str', default => '060406a' );

has analyzer_dir => ( is => 'ro', isa => 'Str', default => 'data/models/morpho_analysis/cs_060406a' ); 

# This will only try to download the morphological dictionary README automatically (and assume the files are 
# in the correct directory), so that we are not giving the morphological dictionary out for free, but allow the users
# to have their own shared directory and copy the files there by themselves.
#
# TODO: create an intelligible warning if the files are not where they're supposed to be.
Readonly my $ANALYZER_DATA => [
    'x.README'    
];

# Maximum word length we let the analyzer take so that it won't fail (use suffixes otherwise)
Readonly my $ANALYZER_MAX_WORD_LENGTH => 45;


# TODO: this will only try to
sub _build_analyzer {

    my $self = shift;
    my $share_dir;
    
    # assume all shared files will be in the same directory (or else CzechMorpho won't work)
    foreach my $data_file (@{$ANALYZER_DATA}){
        $share_dir = require_file_from_share( $self->analyzer_dir . '/CZ' . $self->analyzer_version . $data_file );     
    }
    $share_dir =~ s/\/[^\/]*$/\//; # just take the directory from the last file
    
    return CzechMorpho::Analyzer->new($share_dir);
}

override '_analyze' => sub {
    my ( $self, $wordform ) = @_;
    my @analyses;
    
    # Some simple heuristics 
    
    # avoid words that contain dashes, take just what's after the dash (with a few exceptions)
    my $prefix = '';
    if ( $wordform !~ /^on-line/i 
        && ($wordform =~ m/[^\p{Upper}-]/ || $wordform =~ m/^\p{Upper}{7,}/ || $wordform =~ m/\p{Upper}{7,}$/) 
        && $wordform =~ m/^(.*)-([^-]{3,})$/ ){     
        
        $prefix = $1 . '-';
        $wordform = $2;
    }      

    # The analysis itself
    
    foreach ( $self->_analyzer->analyze($wordform) ) {
        my $analysis_rf = {};
        $analysis_rf->{'lemma'} = $prefix . $_->{'lemma'};
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

=head1 TODO

Fix the following warning that appeared during the reparsing of the CzEng corpus:

  (in cleanup) Can't call method "testFinish" on an undefined value at treex/lib/Treex/Tool/Tagger/Featurama.pm line 49 during global destruction.


=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
