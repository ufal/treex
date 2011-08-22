package Treex::Block::A2A::CS::ReadClauses;

use Moose;
use Treex::Core::Common;
use Treex::Block::A2A::CS::DetectClauses;

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

        Treex::Block::A2A::CS::DetectClauses->plant_seeds( 2, $source_root, $source_root, 1, 1 );
        Treex::Block::A2A::CS::DetectClauses->add_compound_verbs( $source_root, $source_root, 1 );
        foreach ( $source_root->get_descendants() ) { $_->set_clause_number(undef); }
    
        my $clauses_rf    = _annotated_clauses( $segments_rf, $segments_annot_rf );
        my $clause_number = 1;
        my @color         = qw { red green yellow blue orange cyan magenta };
        foreach my $clause ( @{$clauses_rf} ) {
            map {
                if ( defined $_ ) {
                    $_->{clause_number} = $clause_number;
                }
                defined $_ ? $_->form : '##'
            } @{ $clause->{nodes} };
            $clause_number++;
        }

        #   Treex::Block::A2A::CS::DetectClauses->resolve_boundaries($source_root, $source_root);
        #   Treex::Block::A2A::CS::DetectClauses->normalize_clause_ords($source_root);
        #   _merge_apositions($source_root);

        Treex::Block::A2A::CS::DetectClauses->complete_clauses( $source_root, $source_root );
        Treex::Block::A2A::CS::DetectClauses->resolve_boundaries( $source_root, $source_root );
        Treex::Block::A2A::CS::DetectClauses->normalize_clause_ords($source_root);
    }
    else {
        log_info "Missing annotation for $annot_filename. Skipping";
    }
}

sub _merge_apositions {
    my $root          = shift;
    my @ordered_nodes = $root->get_descendants( { ordered => 1 } );
    my %clauses       = map { $_->clause_number => 1 } @ordered_nodes;
    foreach my $clause ( sort { $a <=> $b } keys %clauses ) {
        next if $clause == 0;
        my @clause_nodes = grep { $clause == $_->clause_number} @ordered_nodes;
        my $startord     = $clause_nodes[0]->ord;
        my $endord       = $clause_nodes[-1]->ord;
        @clause_nodes    = grep { $_->ord >= $startord and $_->ord <= $endord } @ordered_nodes;
        my $last_ord     = $clause_nodes[0]->ord;
        my $continuous   = 1;
        for( my $i = 1; $i <= $#clause_nodes; $i++ ) {
            if ( $clause_nodes[$i]->ord > $last_ord + 1 ){
                $continuous = 0;
                last;
            }
            else {
                $last_ord++;  
            }
        }
        #merge continuous clauses without finite verb or imperative
        if ( $continuous and not grep { $_->tag =~ /^V[Bpi]/ } @clause_nodes ) {
            my $prev_node = $clause_nodes[0]->get_prev_node;
            while( $prev_node and not $prev_node->clause_number ){
                $prev_node = $prev_node->get_prev_node;
            }
            if ($prev_node) {
                foreach my $node (@clause_nodes){
                    $node->set_clause_number( $prev_node->clause_number );
                }
            }
        }
    }
}

sub _segment {
    my $root     = shift;
    my @segments = ();
    my $i        = 0;
    foreach my $node ( $root->get_descendants( { ordered => 1 } ) ) {
        next if not $node->parent;
        if ( _is_ref_boundary($node) ) {
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

sub _is_ref_boundary {
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
        my $is_boundary = ( $#{ $segments_rf->[$i] } == 0 and _is_ref_boundary( $segments_rf->[$i][0] ) ) ? 1 : 0;
        my $segment_level = $segments_annot_rf->[$i]{level};
        if ( not $is_boundary ) {
            if ($is_new_clause) {
                if ( ( defined $pending_clause ) and ( $pending_clause->{level} == $segment_level ) ) {
                    $clause         = $pending_clause;
                    $pending_clause = undef;
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
                else {
                    $pending_clause = undef;
                }
            }
        }
        $is_new_clause = ( ( not defined $clause ) or ( not $segments_annot_rf->[$i]->{inside} ) ) ? 1 : 0;
        if ($is_boundary) {
            my $c = $last_for_level{$segment_level};
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
