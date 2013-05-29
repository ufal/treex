package Treex::Block::A2A::Transform::CoordStyle;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2A::Transform::BaseTransformer';

# Shortcuts
has style => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'output coord style - shorcut for other options (e.g. fPhRsHcHpB)',
);

has from_style => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'input coord style - shorcut for other options (e.g. fPhRsHcHpB)',
);

# Output style
has family => (
    is            => 'ro',
    isa           => enum( [qw(Moscow Prague Stanford)] ),
    writer        => '_set_family',
    documentation => 'output coord style family (Prague, Moscow, and Stanford)',
);

has head => (
    is            => 'ro',
    isa           => enum( [qw(left right mixed)] ),
    writer        => '_set_head',
    documentation => 'which node should be the head of the coordination structure',
);

has shared => (
    is            => 'ro',
    isa           => enum( [qw(head nearest)] ),
    writer        => '_set_shared',
    documentation => 'which node should be the head of the shared modifiers',
);

has conjunction => (
    is            => 'ro',
    isa           => enum( [qw(previous following between head)] ),
    writer        => '_set_conjunction',
    documentation => 'conjunction parents (previous, following, between, head)',
);

has punctuation => (
    is            => 'ro',
    isa           => enum( [qw(previous following between)] ),
    writer        => '_set_punctuation',
    documentation => 'punctuation parents (previous, following, between)',
);

has prefer_conjunction => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'In Prague family, if possible prefer conjunction as head instead of commas',
);

# Input style
has from_family => (
    is            => 'ro',
    isa           => enum( [qw(Moscow Prague Stanford autodetect)] ),
    default       => 'autodetect',
    writer        => '_set_from_family',
    documentation => 'input coord style family',
);

has from_head => (
    is            => 'ro',
    isa           => enum( [qw(left right mixed autodetect)] ),
    default       => 'autodetect',
    writer        => '_set_from_head',
    documentation => 'input style head',
);

has from_shared => (
    is            => 'ro',
    isa           => enum( [qw(head nearest autodetect)] ),
    default       => 'autodetect',
    writer        => '_set_from_shared',
    documentation => 'input style shared modifiers parents',
);

has from_conjunction => (
    is            => 'ro',
    isa           => enum( [qw(previous following between head autodetect)] ),
    default       => 'autodetect',
    writer        => '_set_from_conjunction',
    documentation => 'input style conjunction parents',
);

has from_punctuation => (
    is            => 'ro',
    isa           => enum( [qw(previous following between autodetect)] ),
    default       => 'autodetect',
    writer        => '_set_from_punctuation',
    documentation => 'input style punctuation parents',
);

# Other options

has guess_nested => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'try to distinguish nested coordinations from multi-conjunct coordinations',
);

has try_projective_commas => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'try to not introduce new non-projectivities for commas that are not separating conjuncts (but are in CS)',
);

sub BUILD {
    my ( $self, $args ) = @_;

    # TODO: rewrite (code duplication, $self->{attr} etc.)
    my @pars = qw(family head shared conjunction punctuation);
    if ( $self->style ) {
        my $style_regex = 'f[MPS]h[LRM]s[HN]c[PFBH]p[PFB]';
        log_fatal "Parameter 'style' cannot be combined with other parameters"
            if any { $args->{$_} } @pars;
        log_fatal "Prameter 'style' must be in form $style_regex"
            if $self->style !~ /^$style_regex$/;
        $self->_fill_style_from_shortcut( 0, $self->style );
    }
    else {
        for my $par (@pars) {
            log_fatal "Parameter $par (or style) is required" if !$self->{$par};
        }
    }

    if ( $self->from_style ) {
        my $from_style_regex = 'f[MPSA]h[LRMA]s[HNA]c[PFBHA]p[PFBA]';
        log_fatal "Parameter 'from_style' cannot be combined with other parameters"
            if any { $args->{ 'from_' . $_ } } @pars;
        log_fatal "Prameter 'from_style' must be in form $from_style_regex"
            if $self->from_style !~ /^$from_style_regex$/;
        $self->_fill_style_from_shortcut( 1, $self->from_style );
    }

    log_fatal "Prague family must have parameter conjunction=head"
        if $self->family eq 'Prague' && $self->conjunction ne 'head';
    log_fatal "conjunction=head parameter is applicable only for Prague family"
        if $self->family ne 'Prague' && $self->conjunction eq 'head';
    return;
}

my %FAMILY_NAME = (
    M => 'Moscow',
    P => 'Prague',
    S => 'Stanford',
);

my %HEAD_NAME = (
    L => 'left',
    R => 'right',
    M => 'mixed',
);

my %SHARED_NAME = (
    H => 'head',
    N => 'nearest',
);

my %CONJUNCTION_NAME = (
    P => 'previous',
    F => 'following',
    B => 'between',
    H => 'head',
);

my %PUNCTUATION_NAME = (
    P => 'previous',
    F => 'following',
    B => 'between',
);

sub _fill_style_from_shortcut {
    my ( $self, $from, $shortcut ) = @_;
    my $style_regex = 'f([MPSA])h([LRMA])s([HNA])c([PFBHA])p([PFBA])';
    my ( $f, $h, $s, $c, $p ) = ( $shortcut =~ /^$style_regex$/ );
    if ( !$from ) {
        $self->_set_family( $FAMILY_NAME{$f} );
        $self->_set_head( $HEAD_NAME{$h} );
        $self->_set_shared( $SHARED_NAME{$s} );
        $self->_set_conjunction( $CONJUNCTION_NAME{$c} );
        $self->_set_punctuation( $PUNCTUATION_NAME{$p} );
    }
    else {
        $self->_set_from_family( $FAMILY_NAME{$f}           || 'autodetect' );
        $self->_set_from_head( $HEAD_NAME{$h}               || 'autodetect' );
        $self->_set_from_shared( $SHARED_NAME{$s}           || 'autodetect' );
        $self->_set_from_conjunction( $CONJUNCTION_NAME{$c} || 'autodetect' );
        $self->_set_from_punctuation( $PUNCTUATION_NAME{$p} || 'autodetect' );
    }
    return;
}

# function similar to grep, but it deletes the selected items from the array
# So instead of
#   my @picked = grep {/a/} @rest;
#   @rest = grep {!/a/} @rest;
# you can write just
#   my @picked = pick {/a/} @rest;
sub pick(&\@) {
    my ( $code, $array_ref ) = @_;
    my ( @picked, @notpicked );
    foreach (@$array_ref) {
        if ( $code->($_) ) {
            push @picked, $_;
        }
        else {
            push @notpicked, $_;
        }
    }
    @$array_ref = @notpicked;
    return @picked;
}

my %entered;

sub process_atree {
    my ( $self, $atree ) = @_;

    my $from_f = $self->from_family;
    if ( $from_f eq 'Prague' ) {
        $self->detect_prague($atree);
    }
    elsif ( $from_f eq 'Moscow' ) {
        $self->detect_moscow($atree);
    }
    elsif ( $from_f eq 'Stanford' ) {
        $self->detect_stanford($atree);
    }
    else {
        log_fatal "$from_f not implemented";

        #TODO autodetect
    }

    # clean temporary variables, so we save some memory
    %entered = ();
    return;
}

sub detect_prague {
    my ( $self, $node ) = @_;
    my @children = $node->get_children( { ordered => 1 } );

     #warn "dive [" . ($node->form // 'ROOT') . "]\n"; #DEBUG
    
    # If $node is not a head of coordination,
    # just skip it and recursively process its children.
    # In Prague, a node is a head of coordination iff there is at least one is_member child.
    # This is equivalent to checking afun=Coord, but we don't want to rely on afuns.
    if (!any {$_->is_member} $node->get_children() ) {
        foreach my $child (@children) {
            $self->detect_prague($child);
        }
        return $node;
    }

    # So $node is a head of coordination.
    # Detect all coordination participants.
    my @members = grep { $_->is_member } @children;
    my ( @shared, @commas );
    if ( $self->from_shared eq 'nearest' ) {
        @shared = grep { $_->is_shared_modifier } map { $_->get_children } @members;
    }
    else {
        @shared = grep { $_->is_shared_modifier } @children;
    }
    my @todo = grep { !$_->is_member && !$_->is_shared_modifier } @children;
    my @ands = pick { $_->wild->{is_coord_conjunction} } @todo;
    if ( $self->from_punctuation =~ /previous|following/ ) {
        @commas = grep { $self->is_comma($_) } map { $_->get_children } @members;
    }
    else {
        @commas = pick { $self->is_comma($_) } @todo;
    }

    # Recursion
    @members = map { $self->detect_prague($_); } @members;
    @shared  = map { $self->detect_prague($_); } @shared;

    #TODO? @commas, @ands (these should be mostly leaves)

    # Finally add the head (afun=Coord) as either conjunction or comma
    if ( $node->wild->{is_coord_conjunction} ) {
        push @ands, $node;
    }
    else {
        push @commas, $node;
    }

    # Transform the detected coordination
    my $res = { members => \@members, ands => \@ands, shared => \@shared, commas => \@commas, head => $node };
    my $new_head = $self->transform_coord( $node, $res );
    return $new_head;
}

sub detect_stanford {
    my ( $self, $node ) = @_;

    # Don't go twice thru one node
    return $node if $entered{$node};
    $entered{$node} = 1;

    #warn "dive [" . $node->form . "]\n"; #DEBUG

    my @children = $node->get_children( { ordered => 1 } );
    my @members = grep { $_->is_member } @children;

    # If $node is not a head of coordination,
    # just skip it and recursively process its children.
    # In Stanford style, the head of coordination is recognized iff
    #  - there are conjuncts (marked by is_member=1) among its children
    #  - or there are coordinating conjunctions among its children.
    # For CSs with only one conjunct (the head) only the latter holds.
    # E.g. "And I love her." is in some annotation styles considered as a CS
    # with only one conjunct ("love") and one conjunction ("And").
    if ( !@members && !grep { $_->wild->{is_coord_conjunction} } @children ) {
        foreach my $child (@children) {
            $self->detect_stanford($child);
        }
        return $node;
    }

    # Add the head as a member
    push @members, $node;
    @members = sort { $a->ord <=> $b->ord } @members;

    # So $node is a head of coordination.
    # Detect all coordination participants.
    my ( @shared, @commas, @ands );
    if ( $self->from_shared eq 'nearest' ) {
        @shared = grep { $_->is_shared_modifier } map { $_->get_children } @members;
    }
    else {
        @shared = grep { $_->is_shared_modifier } @children;
    }
    my @todo = grep { !$_->is_member && !$_->is_shared_modifier } @children;

    if ( $self->from_conjunction =~ /previous|following/ ) {
        @ands = grep { $_->wild->{is_coord_conjunction} } map { $_->get_children } @members;
    }
    else {
        @ands = pick { $_->wild->{is_coord_conjunction} } @todo;
    }
    @ands = sort { $a->ord <=> $b->ord } @ands;

    my @andmembers = sort { $a->ord <=> $b->ord } ( @ands, @members );
    if ( $self->from_punctuation =~ /previous|following/ ) {
        @commas = grep { $self->is_comma($_) } map { $_->get_children } @andmembers;
    }
    else {
        @commas = pick { $self->is_comma($_) } @todo;
    }

    # Try to distinguish nested coordinations from multi-conjunct coordinations.
    # This is just a heuristics!
    my $new_nested_head;
    if ( $self->guess_nested && @members > 2 && @ands ) {

        # The nested interpretation may be more probable if
        # a) the last conjunction precedes penultimate conjunct, e.g. (C1 and C2) , (C3)
        # if ($ands[-1]->precedes( $members[-2] ))
        # but there are counter-examples like C1 and C2(afun=ExD) C3(afun=ExD).

        # b) if there are two different conjunctions, e.g. (C1 and C2) or (C3).
        if ( @ands > 1 && lc( $ands[0]->form ) ne lc( $ands[1]->form ) ) {
            # TODO: David added a better detection of nested CS to detect_moscow,
            # so duplicate the code here or even better refactor the code into a subroutine.
            ## Suppose the first two members are in the nested coordination
            #  TODO: it might be three or more (but that's very rare)
            my $head_right = ( $self->from_head eq 'right' ) || ( $members[-1] == $node );
            my @nested_members = splice @members, ( $head_right ? -2 : 0 ), 2;
            my $border = $nested_members[ $head_right ? 0 : -1 ];

            # Suppose $border is the borderline between the nested and the outer coordination
            my ( @nested_shared, @nested_ands, @nested_commas );
            if ($head_right) {
                @nested_shared = pick { $border->precedes($_) } @shared;
                @nested_ands   = pick { $border->precedes($_) } @ands;
                @nested_commas = pick { $border->precedes($_) } @commas;
            }
            else {
                @nested_shared = pick { $_->precedes($border) } @shared;
                @nested_ands   = pick { $_->precedes($border) } @ands;
                @nested_commas = pick { $_->precedes($border) } @commas;
            }

            # Process the nested coord. in the same way as the outer coord.
            @nested_members = map { $self->detect_stanford($_); } @nested_members;
            @nested_shared  = map { $self->detect_stanford($_); } @nested_shared;
            my $nested_res = {
                members => \@nested_members,
                ands    => \@nested_ands,
                shared  => \@nested_shared,
                commas  => \@nested_commas,
                head    => $node
            };
            $new_nested_head = $self->transform_coord( $node, $nested_res );
            $node = $new_nested_head;
        }
    }

    @members = map { $self->detect_stanford($_); } @members;
    @shared  = map { $self->detect_stanford($_); } @shared;
    @todo    = map { $self->detect_stanford($_); } @todo;      # private modifiers of the head

    if ($new_nested_head) {
        push @members, $new_nested_head;
    }

    #TODO? @commas, @ands (these should be mostly leaves)

    # Transform the detected coordination
    my $res = { members => \@members, ands => \@ands, shared => \@shared, commas => \@commas, head => $node };
    my $new_head = $self->transform_coord( $node, $res );
    return $new_head;
}

sub detect_moscow {
    my ( $self, $node ) = @_;

    # Don't go twice thru one node
    return $node if $entered{$node};
    $entered{$node} = 1;

    #warn "dive [" . ( $node->form // '' ) . "]\n";    #DEBUG

    my @andmembers = ();
    my $in_chain   = sub {
        $_[0]->is_member || (
            $_[0]->wild->{is_coord_conjunction}
            && $self->from_conjunction =~ /between|autodetect/
            )
    };

    my @queue = ($node);
    my (@todo, @commas);
    while (@queue) {
        my $iter_node = shift @queue;
        my @children = $iter_node->get_children();
        #my @new_andmembers = pick { $in_chain->($_) } @children;
        #log_warn "TODO: solve nested CS under " . $iter_node->get_address() if @new_andmembers > 1;
        #push @commas, pick {$self->is_comma($_)} @children;
        # Only the token immediately preceding a conjunct (or conjunction) can be a coordination comma.
        # Relying just on $self->is_comma() leads to false positives with commas for subordinate clauses.
        my @new_andmembers;
        for my $i (0 .. $#children) {
            if ($in_chain->($children[$i])) {
                push @new_andmembers, $children[$i];
            }
            # TODO: comma can precede also a coordinationg conjunction (@ands) which is not in the chain (unless cB).
            elsif ($self->is_comma($children[$i]) && ($i == $#children || $in_chain->($children[$i+1]))) {
                push @commas, $children[$i];
            }
            else {
                push @todo, $children[$i];
            }
        }
        #push @todo, @children;
        push @andmembers, @new_andmembers;
        push @queue,      @new_andmembers;
    }

    # If $node is not a head of coordination,
    # just skip it and recursively process its children.
    # In Moscow style, the head of coordination is recognized iff
    #  - there are conjuncts (marked by is_member=1) among its children
    #  - or there are coordinating conjunctions among its children.
    if ( !@andmembers ) {
        foreach my $child ( $node->get_children() ) {
            $self->detect_moscow($child);
        }
        return $node;
    }

    # Add the head as a member and sort
    $node->set_is_member(1);
    push @andmembers, $node;
    @andmembers = sort { $a->ord <=> $b->ord } @andmembers;

    my @ands    = grep { $_->wild->{is_coord_conjunction} } @andmembers;
    my @members = grep { $_->is_member } @andmembers;
    if ( $self->from_conjunction eq 'previous' ) {
        push @ands, grep { $_->wild->{is_coord_conjunction} } map { $_->get_children( { following_only => 1 } ) } @members;
    }
    elsif ( $self->from_conjunction eq 'following' ) {
        push @ands, grep { $_->wild->{is_coord_conjunction} } map { $_->get_children( { previous_only => 1 } ) } @members;
    }
    elsif ( $self->from_conjunction eq 'autodetect' ) {
        push @ands, grep { $_->wild->{is_coord_conjunction} } map { $_->get_children() } @members;
    }
    @ands = sort { $a->ord <=> $b->ord } @ands;

    my @shared;
    if ( $self->from_shared eq 'head' ) {
        @shared = grep { $_->is_shared_modifier } $node->get_children();
    }
    else {
        @shared = grep { $_->is_shared_modifier } map { $_->get_children } @members;
    }

    # Try to distinguish nested coordinations from multi-conjunct coordinations.
    # This is just a heuristics!
    my $new_nested_head;
    if ( $self->guess_nested && @members > 2 && @ands ) {

        # The nested interpretation may be more probable if
        # a) the last conjunction precedes penultimate conjunct, e.g. (C1 and C2) , (C3)
        # if ($ands[-1]->precedes( $members[-2] ))
        # but there are counter-examples like C1 and C2(afun=ExD) C3(afun=ExD).

        # b) if there are two different conjunctions, e.g. (C1 and C2) or (C3).

        if ( @ands > 1 && lc( $ands[0]->form ) ne lc( $ands[1]->form ) ) {
            my $head_right = ( $self->from_head eq 'right' ) || ( $members[-1] == $node );
            my $both_in_one_chain = (($head_right && any{$_ eq $ands[0]} $ands[1]->get_descendants) || any{$_ == $ands[1]} $ands[0]->get_descendants ) ? 1 : 0;
            # Suppose the first (or last) two members are in the nested coordination
            #  TODO: it might be three or more (but that's very rare)
            my @nested_members = splice @members, ( $head_right != $both_in_one_chain ? -2 : 0 ), 2;
            my $border = $nested_members[ $head_right != $both_in_one_chain ? 0 : -1 ];
            # Suppose $border is the borderline between the nested and the outer coordination
            my ( @nested_shared, @nested_ands, @nested_commas );
            if ($head_right == $both_in_one_chain) {
                @nested_shared = pick { $_->precedes($border) } @shared;
                @nested_ands   = pick { $_->precedes($border) } @ands;
                @nested_commas = pick { $_->precedes($border) } @commas;
            }
            else {
                @nested_shared = pick { $border->precedes($_) } @shared;
                @nested_ands   = pick { $border->precedes($_) } @ands;
                @nested_commas = pick { $border->precedes($_) } @commas;
            }

            # Process the nested coord. in the same way as the outer coord.
            @nested_members = map { $self->detect_moscow($_); } @nested_members;
            @nested_shared  = map { $self->detect_moscow($_); } @nested_shared;
            my $nested_res = {
                members => \@nested_members,
                ands    => \@nested_ands,
                shared  => \@nested_shared,
                commas  => \@nested_commas,
                head    => $node
            };
            $new_nested_head = $self->transform_coord( $node, $nested_res );
            $node = $new_nested_head;
        }
    }

    #@members = map { $self->detect_moscow($_); } @members;
    @shared  = map { $self->detect_moscow($_); } @shared;
    @todo    = map { $self->detect_moscow($_); } @todo;      # private modifiers of the head

    if ($new_nested_head) {
        push @members, $new_nested_head;
    }

    #TODO? @commas, @ands (these should be mostly leaves)

    # Transform the detected coordination
    my $res = { members => \@members, ands => \@ands, shared => \@shared, commas => \@commas, head => $node };
    my $new_head = $self->transform_coord( $node, $res );
    return $new_head;
}

# Find the nearest previous/following member.
# "Previous/following" is set by $direction, but if no such is found, the other direction is tried.
sub _nearest {
    my ( $self, $direction, $node, @members ) = @_;
    if ( $direction eq 'previous' ) {
        my $prev_mem = first { $_->precedes($node) } reverse @members;
        return $prev_mem if $prev_mem;
        return first { $node->precedes($_) } @members;
    }
    elsif ( $direction eq 'following' ) {
        my $foll_mem = first { $node->precedes($_) } @members;
        return $foll_mem if $foll_mem;
        return first { $_->precedes($node) } reverse @members;
    }
    elsif ( $direction eq 'any' ) {
        my $my_ord = $node->ord;
        my @sorted = sort { abs( $a->ord - $my_ord ) <=> abs( $b->ord - $my_ord ) } @members;
        return $sorted[0];
    }
    else {
        log_fatal "unknown direction '$direction'";
    }
}

sub _dump_res {
    my ( $self, $res ) = @_;
    my $head = $res->{head};
    warn "COORD_DUMP head=" . $head->form . "(id=" . $head->id . ")\n";
    foreach my $type (qw(members ands shared commas)) {
        warn $type . ":" . join( '|', map { $_->form } @{ $res->{$type} } ) . "\n";
    }
    return;
}

# returns new_head
sub transform_coord {
    my ( $self, $old_head, $res ) = @_;
    return $old_head if !$res;

    #$self->_dump_res($res);    #DEBUG
    my $parent = $old_head->get_parent() or return $old_head;
    my @members = sort { $a->ord <=> $b->ord } @{ $res->{members} };

    # @members, @shared, @commas and @ands should be disjunct sets
    # However, some members may be incorrectly included in @commas etc.
    # (because of rare nested cases), so let's filter them out.
    my %is_done = map { $_ => 1 } @members;
    my @shared = map { $is_done{$_} = 1; $_ } grep { !$is_done{$_} } @{ $res->{shared} };
    my @commas = map { $is_done{$_} = 1; $_ } grep { !$is_done{$_} } @{ $res->{commas} };
    my @ands   = map { $is_done{$_} = 1; $_ } grep { !$is_done{$_} } @{ $res->{ands} };

    # Skip if no members
    if ( !@members ) {

        # These cases may be AuxX from appositions or incorrectly detected
        # coordination conjunction, e.g. "A(afun=AuxY) to se podívejme."
        # So I've commented the next line, since most warnings would be false alarms.
        #log_warn "No conjuncts in coordination under " . $parent->get_address;
        return $old_head;
    }

    # Filter incorrectly detected commas: commas should be between members.
    my @noncommas = pick { $_->precedes( $members[0] ) || $members[-1]->precedes($_) } @commas;

    my $new_head;
    my $parent_left = $parent->precedes( $members[0] );
    my $is_left_top = $self->head eq 'left' ? 1 : $self->head eq 'right' ? 0 : $parent_left;

    # Commas should have afun AuxX, conjunctions Coord. They are not is_member.
    # (Except for Prague family, where the head conjunction has always Coord,
    # but that will be solved later.)
    foreach my $sep ( @commas, @ands ) {
        $sep->set_afun( $self->is_comma($sep) ? 'AuxX' : 'Coord' );
        $sep->set_is_member(0);
    }

    # PRAGUE
    if ( $self->family eq 'Prague' ) {

        # Possible heads are @ands (conjunctions), but if missing
        # or if we don't want to distinguish them from @commas (i.e. not $self->prefer_conjunction)
        # then we should include commas as "eligible" for the head.
        if ( !@ands || !$self->prefer_conjunction ) {
            push @ands, @commas;
            @commas = ();
        }
        if ( !@ands ) {
            log_warn "No separators in coordination under " . $parent->get_address;
            
            # We are not able to convert this coordination to Prague family,
            # but we must produce a valid structure, so unmark all members.
            for my $member (@members){
                $member->set_is_member(0);
            }
            return $old_head;
        }
        @ands = sort { $a->ord <=> $b->ord } @ands;

        # Choose one of the possible heads as $new_head,
        # the rest will be treated as commas.
        $new_head = $is_left_top ? shift @ands : pop @ands;
        push @commas, @ands;
        for (@commas) { $_->set_afun('AuxY'); }

        # Rehang the new_head and members
        $self->rehang( $new_head, $parent );
        $new_head->set_afun('Coord');
        foreach my $member (@members) {
            $self->rehang( $member, $new_head );
        }

        # In Prague family, punctuation=between means that
        # commas (and remaining conjunctions) are hanged on the head.
        if ( $self->punctuation eq 'between' ) {
            foreach my $comma (@commas) {
                $self->rehang( $comma, $new_head );
            }
        }
    }

    # STANFORD & MOSCOW
    else {
        my @andmembers = @members;
        $new_head = $is_left_top ? shift @andmembers : pop @andmembers;
        push @andmembers, @ands   if $self->conjunction eq 'between';
        push @andmembers, @commas if $self->punctuation eq 'between';
        @andmembers = sort { $a->ord <=> $b->ord } @andmembers;
        if ( !$is_left_top ) {
            @andmembers = reverse @andmembers;
        }

        # Rehang the members (and conjunctions and commas if "between")
        $self->rehang( $new_head, $parent );
        my $rehang_to = $new_head;
        foreach my $andmember (@andmembers) {
            $self->rehang( $andmember, $rehang_to );
            if ( $self->family eq 'Moscow' ) {
                $rehang_to = $andmember;
            }
        }
    }

    # SET is_member LABELS
    # Generally, is_member=1 iff a given word is a conjunct ("a member of a coordination").
    # However, there are exceptions for each style family:
    # * Prague:   In nested coordinations, also coordination head
    #             (conjunction or comma) can have is_member=1.
    # * Stanford: The coordination head (the first/last conjunct) is NOT marked
    #             as is_member (unless it is also a non-head conjunct of a nested coordination).
    # * Moscow:   Same as Stanford (but may be changed because of problematic
    #             distinguishing of nested coordinations from multi-conjunct coordinations).
    foreach my $member (@members) {
        $member->set_is_member( $member != $new_head );
    }

    # COMMAS (except "between" which is already solved)
    if ( $self->punctuation =~ /previous|following/ ) {
        my @andmembers = sort { $a->ord <=> $b->ord } @members, @ands;
        foreach my $comma (@commas) {
            $self->rehang( $comma, $self->_nearest( $self->punctuation, $comma, @andmembers ) );
        }
    }

    # Commas that were not separating conjunct should remain on the same position
    # (which means if they were below (old) head they should be below (new) head)
    # if they would otherwise result in non-projectivities.
    if ( $self->try_projective_commas ) {
        foreach my $noncomma (@noncommas) {
            my @would_be_nonproj;

            # If it is now non-projective
            if ( $noncomma->parent == $old_head && $noncomma->is_nonprojective() ) {

                # try to rehang it
                $noncomma->set_parent($new_head);

                # and if it is non-projective, then log the change, otherwise revert it
                if ( $noncomma->is_nonprojective() ) {
                    $noncomma->set_parent($old_head);
                    $self->rehang( $noncomma, $new_head );
                }
                else {
                    $noncomma->set_parent($old_head);
                }
            }
        }
    }

    # CONJUNCTIONS (except "between" and "head" which are already solved)
    if ( $self->conjunction =~ /previous|following/ ) {
        foreach my $and (@ands) {
            $self->rehang( $and, $self->_nearest( $self->conjunction, $and, @members ) );
        }
    }

    # SHARED MODIFIERS
    foreach my $sm (@shared) {

        # Note that if there is no following member, nearest previous will be chosen.
        if ( $self->shared eq 'nearest' ) {
            $self->rehang( $sm, $self->_nearest( 'any', $sm, @members ) );
        }
        elsif ( $self->shared eq 'head' ) {
            $self->rehang( $sm, $new_head );
        }
    }

    return $new_head;
}

# Is the given node a coordination separator such as comma or semicolon?
sub is_comma {
    my ( $self, $node ) = @_;
    return $node->form =~ /^[,;]$/ && !$node->is_shared_modifier && ( !$node->is_member || $self->from_family eq 'Prague' );
}

1;

__END__

=head1 NAME

Treex::Block::A2A::Transform::CoordStyle - change the style of coordinations

=head1 SYNOPSIS

  # in scenario:
  A2A::Transform::CoordStyle
         from_family=Stanford
           from_head=right
         from_shared=head
    from_conjunction=following
    from_punctuation=following
         family=Moscow
           head=left
         shared=nearest
    conjunction=between
    punctuation=previous

  #TODO the same using a shortcut
  #A2A::Transform::CoordStyle from_style=fShRsHcFpF style=fMhLsNcBpP
  
=head1 DESCRIPTION

TODO

=head1 PREREQUISITIES

  is_member
  is_shared_modifier
  wild->{is_coord_conjunction}

=head1 SEE ALSO

L<Treex::Block::A2A::SetSharedModifier>,
L<Treex::Block::A2A::SetCoordConjunction>


# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
