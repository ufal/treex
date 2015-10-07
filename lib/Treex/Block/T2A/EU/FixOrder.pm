package Treex::Block::T2A::EU::FixOrder;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

#### TODO: Exceptions


sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $parent = $tnode->get_parent();

    #
    if ($tnode->formeme =~ /^v:/) {

	if (($tnode->gram_verbmod || "") ne "imp") {
	    my ($object) = grep { $_->formeme =~ /:(abs\+X|obj)$/ } $tnode->get_children({following_only=>1});
	    my $child = $tnode->get_children({following_only=>1, first_only=>1});

	    $object->shift_before_node($tnode) if (defined $object);
	    $child->shift_before_node($tnode) if (defined $child);
	}
	else {
	    my ($object) = grep { $_->formeme =~ /:(abs\+X|obj)$/ } $tnode->get_children({preceding_only=>1});

	    $object->shift_after_node($tnode) if (defined $object);
	}
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EU::FixAttributeOrder

=head1 DESCRIPTION



=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by IXA Group, University of the Basque Country (UPV/EHU)
