package Treex::Tool::Coreference::EN::PronAnaphFilter;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter::PersPron;

with 'Treex::Tool::Coreference::NodeFilter';

has 'skip_referential' => ( is => 'ro', isa => 'Bool', default => 0, required => 1);

sub is_candidate {
    my ($self, $t_node) = @_;

    log_warn "Class Treex::Tool::Coreference::EN::PronAnaphFilter is DEPRECATED. Use Treex::Tool::Coreference::NodeFilter::PersPron instead.";

    my $args = {};
    if ($self->skip_referential) {
        $args->{skip_nonref} = 1;
    }

    return Treex::Tool::Coreference::NodeFilter::PersPron::is_pers($t_node, $args);
}

# TODO doc

1;
