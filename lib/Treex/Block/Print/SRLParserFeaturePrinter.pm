package Treex::Block::Print::SRLParserFeaturePrinter;

use Fcntl ':flock';

use Moose;
use Treex::Core::Common;
use Treex::Tool::SRLParser::FeatureExtractor;
use Treex::Tool::SRLParser::PredicateIdentifier;

extends 'Treex::Core::Block';

has 'filename' => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

has 'empty_sign' => (
    is      => 'rw',
    isa     => 'Str',
    default => '_',
);

has 'feature_delim' => (
    is      => 'rw',
    isa     => 'Str',
    default => ' ',
);

sub process_ttree {
    my ( $self, $t_root ) = @_;

    # find all relations (=positive instances) in t-tree
    my %positive_instances;
    foreach my $t_node ($t_root->get_descendants) {
        my $a_node = $t_node->get_lex_anode() or next;
        foreach my $child ($t_node->get_children) {
            my $child_a_node = $child->get_lex_anode() or next;
            $positive_instances{$a_node->id ." ". $child_a_node->id} = $child->functor;
        }
    }
    
    # create positive and negative instances and their classification features
    my $feature_extractor = Treex::Tool::SRLParser::FeatureExtractor->new();
    my $predicate_identifier = Treex::Tool::SRLParser::PredicateIdentifier->new();

    my $zone = $t_root->get_zone;
    my $a_root = $zone->get_atree;
    my @a_nodes = $a_root->get_descendants;

    my @lines;
    foreach my $predicate (@a_nodes) {
        next if not $predicate_identifier->is_predicate($predicate); 
        foreach my $depword (@a_nodes) {
            my $key = $predicate->id ." ". $depword->id;
            my $label = exists $positive_instances{$key} ? $positive_instances{$key} : $self->empty_sign;
            push @lines, $label . $self->feature_delim . $feature_extractor->extract_features($a_root, $predicate, $depword);
        }
    }

    open(my $fw, '>>:utf8', $self->filename) or log_fatal("Could not open " . $self->filename ."\n");
    flock($fw, LOCK_EX);
    print $fw join("\n", @lines);
    print $fw "\n";
    flock($fw, LOCK_UN);
    close($fw);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::SRLParserFeaturePrinter

=head1 DESCRIPTION

Prints (appends) classification features for SRL parser (L<Che et al. 2009|http://ir.hit.edu.cn/~car/papers/conll09.pdf>) of all given training data to one file (locking is ensured when running in parallel).

=head1 PARAMETERS

=over

=item filename

Path to output file to print classification features.

=item feature_delim

Delimiter between features. Default is space, because Maximum Entropy Toolkit
expects spaces between features. 

=item empty_sign

A string for denoting empty or undefined values, such as no semantic relation
in t-tree, no syntactic relation in a-tree, empty values for features, etc.

=back

=head1 AUTHOR

Jana Straková <strakova@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
