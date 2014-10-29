package Treex::Core::Node::Interset;
use Moose::Role;

# with Moose >= 2.00, this must be present also in roles
use MooseX::SemiAffordanceAccessor;
use Treex::Core::Log;
use List::Util qw(first); # TODO: this wouldn't be needed if there was Treex::Core::Common for roles
use Lingua::Interset 2.018;
use Lingua::Interset::FeatureStructure;
use Data::Dumper;

has iset => (
    # Unfortunatelly, the old interface uses $anode->set_iset('tense', 'past'),
    # so set_iset cannot be used as a setter for the whole structure
    # $anode->set_iset(Lingua::Interset::FeatureStructure->new(tense=>'past'))
    is => 'ro',
    isa => 'Lingua::Interset::FeatureStructure',
    lazy_build => 1,
    #builder => '_build_iset',
    handles => [qw(
        is_noun
        is_abbreviation
        is_adjective
        is_adposition
        is_adverb
        is_article
        is_conjunction
        is_coordinator
        is_dual
        is_finite_verb
        is_foreign
        is_hyph
        is_infinitive
        is_interjection
        is_numeral
        is_participle
        is_particle
        is_past
        is_possessive
        is_plural
        is_pronoun
        is_proper_noun
        is_punctuation
        is_reflexive
        is_singular
        is_subordinator
        is_transgressive
        is_typo
        is_verb
        is_wh
    )],
);

sub _build_iset {
    return Lingua::Interset::FeatureStructure->new();
}

# Interset 1.0 legacy method (works with both Interset 1.0 and 2.0 feature structures)
sub is_preposition {my $self = shift; return $self->iset->pos =~ /^(prep|adp)$/;}

#------------------------------------------------------------------------------
# Takes the Interset feature structure as a hash reference (as output by an
# Interset decode() or get_iset_structure() function). For all hash keys that
# are known Interset feature names, sets the corresponding iset attribute.
#
# If the first argument is not a hash reference, the list of arguments is
# considered a list of features and values. Usage examples:
#
#    set_iset(\%feature_structure);
#    set_iset('pos', 'noun');
#    set_iset('pos' => 'noun', 'gender' => 'masc', 'number' => 'sing');
#
# TODO: Note that this is not a proper setter method yet.
# For backward compatibility, it only *adds* features to the Interset feature structure.
# For example:
#   $anode->set_iset(case=>'nom', gender=>'fem');
#   $anode->set_iset(case=>'gen', pos=>'noun');
# Now $anode->get_iset_structure() would return
# {case=>'gen', pos=>'noun', gender=>'fem'}
# If you want to delete a feature, you must explicitely set it to an empty string
#  $anode->set_iset(gender=>'');
# Now: {case=>'gen', pos=>'noun', gender=>''} which is equivalent to
#      {case=>'gen', pos=>'noun'}
#------------------------------------------------------------------------------
sub set_iset{
    my $self = shift;
    my @assignments;
    if ( ref( $_[0] ) =~ /(HASH|Lingua::Interset::FeatureStructure)/ ) {
        @assignments = %{$_[0]};
    }
    else {
        log_fatal "No parameters for 'set_iset'" if @_ == 0;
        log_fatal "Odd parameters for 'set_iset'" if @_%2;
        @assignments = @_;;
    }
    return $self->iset->add(@assignments);
}

#------------------------------------------------------------------------------
# Gets the value of an Interset feature. Makes sure that the result is never
# undefined so the use/strict/warnings creature keeps quiet. It returns undef
# only if we ask for the value of an unknown feature.
#
# If there is a disjunction of values (such as "fem|neut"), this function
# returns just a string with vertical bars as delimiters. The caller can use
# a split() function to get an array, or call get_iset_structure() instead.
#------------------------------------------------------------------------------
sub get_iset{
    my ($self, $feature) = @_;
    my $value = $self->get_attr("iset/$feature");
    # convert arrayref to string, e.g. "fem|neut"
    if ( ref($value) eq 'ARRAY' ) {
        $value = join '|', @$value;
    }
    return $value if defined $value;

    # Check valid feature name only when the feature is missing.
    # TODO: Lingua::Interset::FeatureStructure::set should check for valid feature names.
    if (!Lingua::Interset::FeatureStructure::feature_valid($feature)){

        # TODO: convert all Treex code to Interset 2.0, so the next line is not needed.
        #if ($feature ne 'subpos'){
            log_warn("Querying unknown Interset feature $feature");
        #}
    }

    # Return empty string instead of undef.
    return '';
}

#------------------------------------------------------------------------------
# Gets the values of all Interset features and returns a hash. Any multivalues
# (such as "fem|neut") will be converted to arrays referenced from the hash
# (same as the result of decode() functions in Interset tagset drivers).
#------------------------------------------------------------------------------
sub get_iset_structure
{
    my $self = shift;
    my %f;
    foreach my $feature ( Lingua::Interset::FeatureStructure::known_features() )
    {
        $f{$feature} = $self->get_iset($feature);
        if ( $f{$feature} =~ m/\|/ )
        {
            my @values = split( /\|/, $f{$feature} );
            $f{$feature} = \@values;
        }
    }
    return \%f;
}

#------------------------------------------------------------------------------
# Gets the values of all non-empty Interset features and returns a mixed list
# of features and their values. Useful for displaying features of a node: the
# features are ordered according to their default order in Interset.
#------------------------------------------------------------------------------
sub get_iset_pairs_list
{
    my $self = shift;
    my @list;
    foreach my $feature ( Lingua::Interset::FeatureStructure::known_features() )
    {
        my $value = $self->get_iset($feature);
        unless ( $value eq '' )
        {
            push( @list, $feature, $value );
        }
    }
    return @list;
}

#------------------------------------------------------------------------------
# Return the values of all non-empty Interset features (except for the "tagset" feature).
#------------------------------------------------------------------------------
sub get_iset_values
{
    my $self = shift;
    return map {my $v = $self->get_iset($_); $v ? $v : ()} grep {$_ ne 'tagset'} Lingua::Interset::FeatureStructure::known_features();
}


#------------------------------------------------------------------------------
# Returns list of non-empty Interset features and their values as one string
# suitable for the FEAT column in the CoNLL format. Besides Write::CoNLLX, this
# method should be called also from other blocks that work with the CoNLL
# format, such as W2A::ParseMalt.
#------------------------------------------------------------------------------
sub get_iset_conll_feat
{
    my $self = shift;
    my @list = $self->get_iset_pairs_list();
    my @pairs;
    for(my $i = 0; $i<=$#list; $i += 2)
    {
        my $pair = "$list[$i]=$list[$i+1]";
        # Interset values might contain vertical bars if there are disjunctions of values.
        # Change them to something else because vertical bars will be used to separate pairs in the FEAT string.
        $pair =~ s/\|/;/g;
        push(@pairs, $pair);
    }
    return join('|', @pairs);
}

#------------------------------------------------------------------------------
# Tests multiple Interset features simultaneously. Input is a list of feature-
# value pairs, return value is 1 if the node matches all these values. This
# function is an abbreviation for a series of get_iset() calls in an if
# statement:
#
# if($node->match_iset('pos' => 'noun', 'gender' => 'masc')) { ... }
#------------------------------------------------------------------------------
sub match_iset
{
    my $self = shift;
    my @req  = @_;
    for ( my $i = 0; $i <= $#req; $i += 2 )
    {
        my $feature  = $req[$i];
        my $expected = $req[$i+1];
        confess("Undefined feature") unless ($feature);
        my $value = $self->get_iset($feature);
        my $comp =
            $expected =~ s/^\!\~// ? 'nr' :
            $expected =~ s/^\!//   ? 'ne' :
            $expected =~ s/^\~//   ? 're' : 'eq';
        if (
            $comp eq 'eq' && $value ne $expected ||
            $comp eq 'ne' && $value eq $expected ||
            $comp eq 're' && $value !~ m/$expected/  ||
            $comp eq 'nr' && $value =~ m/$expected/
           )
        {
            return 0;
        }
    }
    return 1;
}


# Methods should not be mixed with (public) functions in one API.
# Moose roles should provide only methods (no functions).
sub list_iset_values {log_fatal 'use Lingua::Interset::FeatureStructure::known_features instead';}
sub is_known_iset{ log_fatal 'use Lingua::Interset::FeatureStructure::value_valid instead';}
sub sort_iset_values {log_fatal 'use Lingua::Interset::FeatureStructure::known_features instead';}

# Goal: convert multivalues from arrays to strings:
# e.g. iset/gender = ["fem", "neut"] becomes iset/gender = "fem|neut"
# to enable storing in a PML file.
# Based on get_iset_pairs_list,
# but stores the values into 'iset/feature' attributes instead of returning them.
sub serialize_iset {
    my ($self) = @_;
    foreach my $feature ( Lingua::Interset::FeatureStructure::known_features() ) {
        my $value = $self->get_iset($feature);
        unless ( $value eq '' ) {
            $self->set_attr("iset/$feature", $value);
        }
    }
    return;
}

# Goal: convert multivalues from strings to arrays:
# e.g. iset/gender = "fem|neut" becomes iset/gender = ["fem", "neut"]
sub deserialize_iset {
    my ($self) = @_;

    if (! $Treex::Core::Config::running_in_tred) {
        # iset
        # ttred does not like arrayrefs so only unserilaize if not in ttred
        if ($self->iset) {
            # this looks a bit weird,
            # but it ensures correct deserialization of multivalues,
            # i.e. turning e.g. "fem|neut" into ["fem", "neut"]
            $self->set_iset($self->iset);
        }
    }
    
    # iset_dump
    # (backward compatibility for files
    # created when iset_dump was used to store iset)
    if ( $self->{iset_dump} ) {
        $self->set_iset( eval "my " . $self->{iset_dump} . '; return $VAR1' ); ## no critic (ProhibitStringyEval)
        # iset_dump is deprecated
        delete $self->{iset_dump};
        if ($Treex::Core::Config::running_in_tred) {
            # ttred does not like arrayrefs so serialize back to strings for it
            $self->serialize_iset();
        }
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Node::Interset

=head1 DESCRIPTION

Moose role for nodes that have the Interset feature structure.

=head1 ATTRIBUTES

=over

=item iset/*

Attributes corresponding to Interset features.

=back

=head1 METHODS

=head2 Access to Interset features

=over

=item my $boolean = $node->match_iset('pos' => 'noun', 'gender' => '!masc', ...);

Do the feature values of this node match the specification?
(Values of other features do not matter.)
A value preceded by exclamation mark is tested on string inequality.
A value preceded by a tilde is tested on regex match.
A value preceded by exclamation mark and tilde is tested on regex mismatch.
Other values are tested on string equality.

=back


=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2013, 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
