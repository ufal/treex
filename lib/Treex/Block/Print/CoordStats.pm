package Treex::Block::Print::CoordStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has summary_only => ( is => 'rw', default => 0 );
has _stats => ( is => 'ro', default => sub { {} } );

sub process_bundle {

    my ( $self, $bundle ) = @_;
    # The second argument to get_zone() is selector and it is empty so we will never get the xx_orig zone.
    my $zone     = $bundle->get_zone('mul');
    my $language = $zone->language;
    my $set      = $zone->get_document->path =~ /train/ ? 'train' : 'test';
    my $atree    = $zone->get_atree;
    my $stats    = $self->_stats();

    foreach my $node ( $atree->get_descendants( { add_self => 1 } ) ) {

        my @features;
        if ( $node->is_root ) {
            push @features, 'is_root';
        }

        if ( ( $node->afun || '' ) eq 'Coord' ) {
            push @features, 'is_coord_head';
            if ( $node->get_parent && ( $node->get_parent->afun || '' ) eq 'Coord' )
            {
                push @features, 'is_nested_inner';
            }
            if ( grep { ( $_->afun || '' ) eq 'Coord' } $node->get_children )
            {
                push @features, 'is_nested_outer';
            }
            # Number of conjuncts.
            my @conjuncts = grep {$_->is_member()} ($node->children());
            my $n = scalar(@conjuncts);
            $stats->{max_conjuncts} = $n if(!exists($stats->{max_conjuncts}) || $n>$stats->{max_conjuncts});
            $n = "5+" if($n>=5);
            push @features, "is_coord_of_$n";
            if(@conjuncts)
            {
                my $pos = $conjuncts[0]->get_iset('pos');
                $pos = 'xxx' if($pos eq '');
                push @features, "is_coord_of_$pos";
            }
        }

        if ( $node->is_member ) {
            push @features, 'is_member';
        }

        if ( $node->is_shared_modifier ) {
            push @features, 'is_shared_modif';
        }
        elsif ( $node->parent && $node->parent->is_member && !grep {$_->is_member && $_->ord < $node->ord} $node->parent->parent->children ) {
            push @features, 'is_pmod_of_first_conjunct';
        }

        if ( $node->wild->{is_coord_conjunction} ) {
            push @features, 'is_coord_conjunction';
            my $form = lc($node->form() // '');
            push @features, "is_coord_conjunction:$form" unless($form eq '');
        }

        unless($self->summary_only())
        {
            print join "\t", ( $language, $set, @features );
            print "\n";
        }
        # Count the features in the hash.
        foreach my $feature ('token', @features)
        {
            $stats->{$feature}++;
        }
    }

    return;
}

sub process_end
{
    my $self  = shift;
    my $stats = $self->_stats();
    # Compute aggregated statistics.
    $stats->{x_coord_per_sentence} = $stats->{is_coord_head} / $stats->{is_root};
    $stats->{x_coord_per_token} = $stats->{is_coord_head} / $stats->{token};
    $stats->{x_conjuncts_per_coord} = $stats->{is_member} / $stats->{is_coord_head};
    $stats->{x_smod_per_coord} = $stats->{is_shared_modif} / $stats->{is_coord_head};
    $stats->{x_pmod_per_coord} = $stats->{is_pmod_of_first_conjunct} / $stats->{is_coord_head};
    $stats->{x_nested_per_coord} = $stats->{is_nested_inner} / $stats->{is_coord_head};
    $stats->{x_nested_per_sentence} = $stats->{is_nested_inner} / $stats->{is_root};
    $stats->{x_verbal_per_coord} = $stats->{is_coord_of_verb} / $stats->{is_coord_head};
    my @features = sort(keys(%{$stats}));
    foreach my $feature (@features)
    {
        next if($feature =~ m/^is_coord_conjunction:/ && $stats->{$feature}<10);
        print { $self->_file_handle() } ("$feature\t$stats->{$feature}\n");
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::CoordStats

=head1 DESCRIPTION

Printint data for counting occurrences of things related
to coordination constructions.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>,
Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
