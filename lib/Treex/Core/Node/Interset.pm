package Treex::Core::Node::Interset;

use MooseX::Role::Parameterized;

parameter interset_attribute => (
  isa      => 'Str',
  default  => 'iset',
);

use Treex::Core::Log;
use List::Util qw(first); # TODO: this wouldn't be needed if there was Treex::Core::Common for roles
use Lingua::Interset 2.050;
use Lingua::Interset::FeatureStructure;
use Data::Dumper;

# "role" is a semi-keyword imported from MooseX::Role::Parameterized
role {
my $role_parameters = shift;
my $interset_attribute = $role_parameters->interset_attribute;

has $interset_attribute => (
    # Unfortunatelly, the old interface uses $anode->set_iset('tense', 'past'),
    # so set_iset cannot be used as a setter for the whole structure
    # $anode->set_iset(Lingua::Interset::FeatureStructure->new(tense=>'past'))
    is => 'ro',
    isa => 'Lingua::Interset::FeatureStructure',
    lazy_build => 1,
    #builder => "_build_$interset_attribute",
    handles => [qw(
        matches
        upos
        set_upos
        is_noun
        is_abbreviation
        is_active
        is_adjective
        is_adposition
        is_adverb
        is_affirmative
        is_article
        is_cardinal
        is_common_gender
        is_comparative
        is_conditional
        is_conjunction
        is_coordinator
        is_dual
        is_feminine
        is_finite_verb
        is_foreign
        is_gerund
        is_hyph
        is_infinitive
        is_interjection
        is_masculine
        is_modal
        is_negative
        is_neuter
        is_numeral
        is_ordinal
        is_participle
        is_particle
        is_past
        is_personal_pronoun
        is_possessive
        is_plural
        is_pronoun
        is_proper_noun
        is_punctuation
        is_reflexive
        is_singular
        is_subordinator
        is_superlative
        is_supine
        is_symbol
        is_transgressive
        is_typo
        is_verb
        is_wh
    )],
   # Note that we cannot export
   # $anode->iset->is_auxiliary as it would clash with the existing $anode->is_auxiliary
   # $tnode->dset->is_passive as it would clash with the existing $tnode->is_passive

);

method "_build_$interset_attribute" => sub {
    return Lingua::Interset::FeatureStructure->new();
};

# Interset 1.0 legacy method (works with both Interset 1.0 and 2.0 feature structures)
method is_preposition => sub {
    my $self = shift;
    return $self->iset->pos =~ /^(prep|adp)$/;
};



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
method set_iset => sub {
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
    return $self->$interset_attribute->add(@assignments);
};



#------------------------------------------------------------------------------
# Gets the value of an Interset feature. Makes sure that the result is never
# undefined so the use/strict/warnings creature keeps quiet. It returns undef
# only if we ask for the value of an unknown feature.
#
# If there is a disjunction of values (such as "fem|neut"), this function
# returns just a string with vertical bars as delimiters. The caller can use
# a split() function to get an array, or call get_iset_structure() instead.
#------------------------------------------------------------------------------
method get_iset => sub {
    my ($self, $feature) = @_;
    my $value = $self->get_attr("$interset_attribute/$feature");
    # convert arrayref to string, e.g. "fem|neut"
    if ( ref($value) eq 'ARRAY' ) {
        $value = join '|', @$value;
    }
    return $value if defined $value;

    # Check valid feature name only when the feature is missing.
    # TODO: convert all Treex code to Interset 2.0, so that no checking is needed.
    if (!Lingua::Interset::FeatureStructure::feature_valid($feature)) {
        log_warn("Querying unknown Interset feature $feature");
    }

    # Return empty string instead of undef.
    return '';
};



#------------------------------------------------------------------------------
# Gets the values of all Interset features and returns a hash. Any multivalues
# (such as "fem|neut") will be converted to arrays referenced from the hash
# (same as the result of decode() functions in Interset tagset drivers).
#------------------------------------------------------------------------------
method get_iset_structure => sub
{
    my $self = shift;
    my $iset = $self->$interset_attribute; # iset or dset
    my %f;
    foreach my $feature ( $iset->get_nonempty_features() )
    {
        $f{$feature} = $iset->get_joined($feature);
        if ( $f{$feature} =~ m/\|/ )
        {
            my @values = split( /\|/, $f{$feature} );
            $f{$feature} = \@values;
        }
    }
    return \%f;
};

#------------------------------------------------------------------------------
# Return the values of all non-empty Interset features (except for the "tagset" and "other" features).
#------------------------------------------------------------------------------
method get_iset_values => sub
{
    my $self = shift;
    return map {$self->get_iset($_)} grep {$_ !~ 'tagset|other'} $self->$interset_attribute->get_nonempty_features();
};

#------------------------------------------------------------------------------
# The inverse of iset->as_string_conllx -- takes a feat string which is the
# result of calling iset->as_string_conllx, and sets Interset feature values
# according to that string.
#------------------------------------------------------------------------------
method set_iset_conll_feat => sub {
    my ($self, $feat_string) = @_;
    my @pairs = split /\|/, $feat_string;
    foreach my $pair (@pairs) {
        $pair =~ s/;/|/g;
        my ($feature, $value) = split /=/, $pair;
        $self->set_iset($feature, $value);
    }
    return;
};

#------------------------------------------------------------------------------
# Tests multiple Interset features simultaneously. Input is a list of feature-
# value pairs, return value is 1 if the node matches all these values. This
# function is an abbreviation for a series of get_iset() calls in an if
# statement:
#
# if($node->match_iset('pos' => 'noun', 'gender' => 'masc')) { ... }
#------------------------------------------------------------------------------
method match_iset => sub {
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
};

# Goal: convert multivalues from arrays to strings:
# e.g. iset/gender = ["fem", "neut"] becomes iset/gender = "fem|neut"
# to enable storing in a PML file.
method serialize_iset => sub {
    my ($self) = @_;
    foreach my $feature ( $self->$interset_attribute->get_nonempty_features() ) {
        my $value = $self->get_iset($feature);
        unless ( $value eq '' ) {
            $self->set_attr("$interset_attribute/$feature", $value);
        }
    }
    return;
};



# Goal: convert multivalues from strings to arrays:
# e.g. iset/gender = "fem|neut" becomes iset/gender = ["fem", "neut"]
method deserialize_iset => sub {
    my ($self) = @_;

    if (! $Treex::Core::Config::running_in_tred) {
        # iset
        # ttred does not like arrayrefs so only unserilaize if not in ttred
        if ($self->$interset_attribute) {
            # this looks a bit weird,
            # but it ensures correct deserialization of multivalues,
            # i.e. turning e.g. "fem|neut" into ["fem", "neut"]
            $self->set_iset($self->$interset_attribute);
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
};


}; # end of "role {"

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

Copyright © 2011, 2013, 2014, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
