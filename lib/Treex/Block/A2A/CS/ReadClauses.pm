package Treex::Block::A2A::CS::ReadClauses;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

#has '+language'       => ( required => 1 );
#has 'source_language' => ( is       => 'rw', isa => 'Str', lazy_build => 1 );
#has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );
#has 'flatten'         => ( is       => 'rw', isa => 'Bool', default => 0 );
#has 'align'           => ( is       => 'rw', isa => 'Bool', default => 0 );

has from => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'clause annotation .seg files prefix',
    default       => '.',
);

binmode STDOUT, ":utf8";

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $source_zone = $bundle->get_zone( $self->language, $self->selector );
    my $source_root = $source_zone->get_atree;
    my $segments_rf = _segment($source_root);
    my $s           = join(
        ' | ',
        map {
            join( ' ', map { $_->form } @{$_} )
            } @{$segments_rf}
    );
    my $annot_filename = $source_root->id;
    $annot_filename =~ s/^a-//;
    my $segments_annot_rf = _read_annotation( $self->from . '/' . $annot_filename . '.seg' );
    my $is_annot_ok = $#{$segments_rf} == $#{$segments_annot_rf} ? 1 : 0;
    if ($is_annot_ok) {
        my $clauses_rf    = _annotated_clauses( $segments_rf, $segments_annot_rf );
        my $clause_number = 1;
        my @color         = qw { red green yellow blue orange cyan magenta };
        foreach my $clause ( @{$clauses_rf} ) {
            map {
                if ( defined $_ ) {
                    $_->{clause_number} = $clause_number;

                    #$_->{clause_level} = $clause->{level};
                }
                defined $_ ? $_->form : '##'
            } @{ $clause->{nodes} };
            $clause_number++;
        }
        _resolve_boundaries( $source_root, $source_root );
        _normalize_clause_ords($source_root);
    }
    else {
        log_info "Missing annotation for $annot_filename. Skipping";

        #        print "Segments /". $#{$segments_rf} . "\t" . $#{$segments_annot_rf} . "/\n";
    }
}

sub _resolve_boundaries {
    my ( $node, $root ) = @_;
    foreach my $child ( $node->get_children ) {
        _resolve_boundaries( $child, $root );
    }
    if ( not defined $node->clause_number ) {
        my @children = $node->get_children( { ordered => 1 } );
        my $first_child = ( grep { $_->clause_number } @children )[0];
        if ($first_child) {
            $node->set_clause_number( $first_child->clause_number );
            foreach my $orphan ( grep { not $_->clause_number } @children ) {
                $orphan->set_clause_number( $node->clause_number );
            }
        }
        elsif ( $node->get_parent and $node->get_parent->clause_number ) {
            $node->set_clause_number( $node->get_parent->clause_number );
        }
    }
}

sub _normalize_clause_ords {
    my $root      = shift;
    my $i         = 1;
    my %reord     = ();
    my @all_nodes = grep { $_->clause_number } $root->get_descendants( { ordered => 1 } );
    map {
        if ( not exists $reord{ $_->clause_number } ) {
            $reord{ $_->clause_number } = $i;
            $i++;
        }
    } @all_nodes;
    foreach my $node (@all_nodes) {
        $node->set_clause_number( $reord{ $node->clause_number } );
    }
}

sub _segment {
    my $root     = shift;
    my @segments = ();
    my $i        = 0;
    foreach my $node ( $root->get_descendants( { ordered => 1 } ) ) {
        next if not $node->parent;
        if ( _is_boundary($node) ) {
            $i++ if $#{ $segments[$i] } >= 0;
            push @{ $segments[$i] }, $node;
            $i++;
        }
        else {
            push @{ $segments[$i] }, $node;
        }
    }
    return \@segments;
}

sub _is_boundary {
    my $node = shift;
    return (
        $node->form =~ m/^(?:,|:|;|\.|\?|!|-|–|-|—|\(|\[|\{|\)|\]|\}|'|\\|„|“|“|”|"|«|»|‚|‛|‘|’|‹|›)$/ or
            $node->tag =~ m/^J\^/
    ) ? 1 : 0;
}

sub _read_annotation {
    my $filename   = shift;
    my @annotation = ();
    open( my $file, '<', $filename ) or return [];
    <$file>;    #dummy id
    while (<$file>) {
        my ( $level, $inside_of_clause ) = split /\s+/;
        push @annotation, {
            level  => $level,
            inside => $inside_of_clause,
        } if defined $inside_of_clause;
    }
    close $file;
    return \@annotation;
}

sub _annotated_clauses {
    my ( $segments_rf, $segments_annot_rf ) = @_;
    my @clauses        = ();
    my $clause         = undef;
    my $pending_clause = undef;    # [ $level, [ nodes ] ]
    my $is_new_clause  = 1;
    my %last_for_level;
    for ( my $i = 0; $i <= $#{$segments_rf}; $i++ ) {
        my $is_boundary = ( $#{ $segments_rf->[$i] } == 0 and _is_boundary( $segments_rf->[$i][0] ) ) ? 1 : 0;
        my $segment_level = $segments_annot_rf->[$i]{level};
        if ( not $is_boundary ) {
            if ($is_new_clause) {
                if ( ( defined $pending_clause ) and ( $pending_clause->{level} == $segment_level ) ) {
                    $clause         = $pending_clause;
                    $pending_clause = undef;

                    #                   push @{$clause->{nodes}}, undef; # undef as placeholder
                }
                else {
                    push @clauses, { level => $segment_level, nodes => [] };
                    $clause = $clauses[$#clauses];
                }
            }
            push @{ $clause->{nodes} }, @{ $segments_rf->[$i] };
            if ( not exists $last_for_level{$segment_level} ) {
                $last_for_level{$segment_level} = $clause;
            }
            if ( ( not defined $pending_clause ) or ( ref($pending_clause) and ref($clause) and $pending_clause == $clause ) ) {
                if ( $segments_annot_rf->[$i]->{inside} ) {
                    $pending_clause = $clause;
                }
                else
                {
                    $pending_clause = undef;
                }
            }
        }
        $is_new_clause = ( ( not defined $clause ) or ( not $segments_annot_rf->[$i]->{inside} ) ) ? 1 : 0;
        if ($is_boundary) {
            my $c = $last_for_level{$segment_level};

            #            if ($clause) {
            #               push @{ $c->{nodes} }, @{ $segments_rf->[$i] };
            #            }
        }
        if ($is_new_clause) {
            $clause = undef;
        }
    }
    return \@clauses;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::CS::ReadClauses

=head1 DESCRIPTION

This block reads annotation of segments and clauses. The .seg files are hopefully used in full complience with the SegView tool: https://svn.ms.mff.cuni.cz/svn/segmentace

=head1 PARAMETERS

=over

=item C<from>

Prefix of the directory containing *.seg files. The files are matched with corresponding sentences based on the original PDT 2.0 ids.

=back

=head1 AUTHOR

Jan Popelka <popelka@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
