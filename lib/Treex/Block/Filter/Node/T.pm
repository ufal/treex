package Treex::Block::Filter::Node::T;

use Moose::Role;
use Treex::Core::Common;

use Treex::Tool::Coreference::NodeFilter::PersPron;
use Treex::Tool::Coreference::NodeFilter::RelPron;
use Treex::Block::My::CorefExprAddresses;

requires 'process_filtered_tnode';

has 'anaph_type' => ( is => 'ro', isa => 'Str', default => 'all' );

sub get_types {
    my ($node) = @_;
    my $types;
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => 1})) {
        $types->{perspron} = 1;
        $types->{all} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($node, {expressed => -1})) {
        #$type = "perspron_unexpr";
        $types->{zero} = 1;
        $types->{all} = 1;
    }
    if (Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($node)) {
        $types->{relpron} = 1;
        $types->{all} = 1;
    }
    if (Treex::Block::My::CorefExprAddresses::_is_cor($node)) {
        #$type = "cor";
        $types->{zero} = 1;
        $types->{all} = 1;
    }
    #elsif (Treex::Block::My::CorefExprAddresses::_is_cs_ten($node)) {
    #    $type = "ten";
    #}
    return $types;
}


sub process_tnode {
    my ($self, $tnode) = @_;
    
    my $types = get_types($tnode);
    return if (!$types->{$self->anaph_type});

    $tnode->wild->{filter_types} = join " ", grep {$_ ne "all"} keys %$types;
    $self->process_filtered_tnode($tnode);
}

1;
