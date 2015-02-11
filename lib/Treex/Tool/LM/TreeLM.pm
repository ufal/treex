package Treex::Tool::LM::TreeLM;
use Treex::Core::Common;
use utf8;
use autodie;

use Class::Std;
use Readonly;
use Storable;
use List::Util qw(sum);
use Scalar::Util qw(weaken);

Readonly my $LOG2 => log(2);
my $ALL = '<ALL>';
Readonly my $USAGE       => 'my $model =Treex::Tool::LM::TreeLM->new({dir=>"path/to/models/"});';
Readonly my $DEFAULT_DIR => $ENV{TMT_ROOT} . '/share/data/models/language/cs/';

#TODO: use attributes so each instance can have its own models
# Each instance of this class has its model...
my %model_of : ATTR;

# ...but those models are shared across all instances if loaded from the same file name
my %loaded_models;

# Directory of a model is a readonly attribute
my %dir_of : ATTR( :init_arg<dir> :get<dir> );

sub log2 { return log( $_[0] ) / $LOG2; }

my ( $cLgFdLd, $cPgFdLd );

sub BUILD {
    log_fatal('Incorrect number of arguments') if @_ != 3;
    my ( $self, $id, $arg_ref ) = @_;
    my $dir = $arg_ref->{'dir'} || $DEFAULT_DIR;
    log_fatal("Dir '$dir' not accesible.\n$USAGE") if !-d $dir;
    $dir_of{$id} = $dir;

    log_info("Loading tree language models from '$dir'...");
    $cLgFdLd = _load_plsgz( $dir . 'c_LgFdLd.pls.gz' );
    $cPgFdLd = _load_plsgz( $dir . 'c_PgFdLd.pls.gz' );

    # If this model has been loaded before, just reuse it
    #return if defined( $model_of{$id} = $loaded_models{$filename} );
    #log_fatal("Could not read file '$filename'.") if ( !-r $filename );
    #    $loaded_models{$filename} = $model_ref;
    #    $model_of{$id}            = $model_ref;
    #    weaken $loaded_models{$filename};
    return;
}

sub _load_plsgz {
    my ($filename) = @_;
    open my $PLSGZ, '<:gzip', $filename;
    my $model = Storable::fd_retrieve($PLSGZ);
    log_fatal("Could not parse perl storable model: '$filename'.") if ( !defined $model );
    close $PLSGZ;
    return $model;
}

sub get_logprob_LdFd_given_Lg {
    return log2( get_prob_LdFd_given_Lg(@_) );
}

sub get_prob_LdFd_given_Lg {
    my ( $self, $Ld, $Fd, $Lg, $verbose ) = @_;
    my $Pg = $Lg->get_pos();
    my $Pd = $Ld->get_pos();
    
    # Get count of governing lemma
    my $cLg_FdLd = $cLgFdLd->[$$Lg];
    my $nLg = $cLg_FdLd->{$ALL} || 0;
    print STDERR "Lg=$Lg (id=$$Lg #=$nLg)\tLd=$Ld (id=$$Ld)\tFd=$Fd\n" if $verbose;

    # This TreeLM is trained on t-nodes, so no POS =~ /[RZX]/.
    # Also conjunctions (J) were discarded when training.
    # So there should be uniform distribution???
    if ($Pd !~ /[NAPCVDIT]/){
        print STDERR "result=0.001 (Pd !~ /[NAPCVDIT]/)\n" if $verbose;
        return 0.001;
    }

    # Governing lemma not seen -> fallback to P(Ld,Fd|Pg)
    if ( !$nLg ) {
        my $nPg     = $cPgFdLd->{$Pg}{$ALL} || 1;
        my $nPgFdLd = $cPgFdLd->{$Pg}{$Fd}{$$Ld} || _check( $Ld->get_pos(), $Fd );
        my $result  = $nPgFdLd / $nPg;
        print STDERR "#PgFdLd=$nPgFdLd\t#Pg=$nPg\n$result = result\n" if $verbose;
        return $result;
    }

    # p2 = P(Fd|Lg) * P(Ld|Fd,Pg)
    my $cLgFd_Ld = $cLg_FdLd->{$Fd};
    my $cPgFd_Ld = $cPgFdLd->{$Pg}{$Fd};    
    my $nPgFd    = $cPgFd_Ld->{$ALL} || 1;
    my $nPg      = $cPgFdLd->{$Pg}{$ALL};
    my $pFd_Pg   = $nPgFd / $nPg;
    my $nLgFd    = $cLgFd_Ld->{$ALL} || $pFd_Pg;
    
    my $nPgFdLd  = $cPgFd_Ld->{$$Ld} || _check( $Ld->get_pos(), $Fd );
    
    my $pFd_Lg   = $nLgFd / $nLg;
    my $pLd_FdPg = $nPgFdLd / $nPgFd;
    my $p2       = $pFd_Lg * $pLd_FdPg;

    # p1 = P(Ld,Fd|Lg)
    my $nLgFdLd  = $cLgFd_Ld->{$$Ld} || $pLd_FdPg;
    my $p1       = $nLgFdLd / $nLg;

    # Get weights
    # TODO: jen nastrel, vahy bude treba pocitat lepe
    my $w1 = ( $nLg > 50_000 ? 1 : ( $nLg / 50_000 ) ) * 0.95;
    if ($Fd =~ /^v/) {$w1 *= 0.01;}
    my $w2 = 1 - $w1;

    # Return linear combination of probs and weights
    my $result = $w1 * $p1 + $w2 * $p2;
    if ($verbose) {
        print STDERR "#LgFdLd = $nLgFdLd\t#LgFd = $nLgFd\t#PgFdLd = $nPgFdLd\t";
        print STDERR "P(Fd|Lg)=$pFd_Lg\tP(Ld|FdPg)=$pLd_FdPg\n";
        print STDERR "$p1 * $w1 = P(Ld=$Ld, Fd=$Fd | Lg=$Lg) * w1\n";
        print STDERR "$p2 * $w2 = P(Fd=$Fd | Lg=$Lg) * P(Ld=$Ld | Fd=$Fd, Pg=$Pg) * w2\n";
        print STDERR "$result = result\n";
    }
    return $result;
}

sub _check {
    my ( $l_pos, $formeme ) = @_;
    return is_pos_and_formeme_compatible( $l_pos, $formeme ) ? 1 : 0.00001;
}

sub is_pos_and_formeme_compatible {
    my ( $l_pos, $formeme ) = @_;
    my ($f_sempos) = $formeme =~ /^([^:]+):/;

    # This should not happen, but let's say it's ok to make it robust.
    return 1 if !$f_sempos || !$l_pos;

    # n:poss formemes can have POS only: A(otcův,matčin) or P(můj)
    return 1 if $formeme eq 'n:poss' && $l_pos eq 'A';

    # Basic pos-to-sempos constraints.
    # Moreover, pronouns(P) and numerals(C) are allowed for some sempos.
    return 1 if $f_sempos eq 'n'   && $l_pos =~ /N|P|C/;
    return 1 if $f_sempos eq 'adj' && $l_pos =~ /A|P|C/;
    return 1 if $f_sempos eq 'adv' && $l_pos =~ /D|C/;
    return 1 if $f_sempos eq 'v' && $l_pos eq 'V';

    return 0;
}

1;

__END__

# This implementation should be better to understand (and more sound);
# we take Lg Fd Ld as a trigram and Pg Fd Ld as a backoff (but interpolation) trigram.
# However, its performance in translation is slightly worse than the original implementation.
sub INTERPOLATIONget_prob_LdFd_given_Lg {
    my ( $self, $Ld, $Fd, $Lg, $verbose ) = @_;
    my $Pg = $Lg->get_pos();
    my $Pd = $Ld->get_pos();
    
    # Pointers to the two data structures
    my $cLg_FdLd = $cLgFdLd->[$$Lg];
    my $cLgFd_Ld = $cLg_FdLd->{$Fd};

    my $cPg_FdLd = $cPgFdLd->{$Pg};
    my $cPgFd_Ld = $cPg_FdLd->{$Fd};

    # Counts
    my $nLg      = $cLg_FdLd->{$ALL} || 0;
    my $nLgFd    = $cLgFd_Ld->{$ALL} || 0;
    my $nLgFdLd  = $cLgFd_Ld->{$$Ld} || 0;

    # TODO: we need cFdLd data structure, let's use the current structures meanwhile
    my $nLd      = $cLgFdLd->[$$Ld]{$ALL} || 0; 
    my $nLdFd    = sum map {$cPgFdLd->{$_}{$Fd}{$Ld} ||0} qw(N A P C V D I T);
    my $nFd      = sum map {$cPgFdLd->{$_}{$Fd}{$ALL}||0} qw(N A P C V D I T);

    my $nPg      = $cPg_FdLd->{$ALL} || 0;
    my $nPgFd    = $cPgFd_Ld->{$ALL} || 0; #1;
    my $nPgFdLd  = $cPgFd_Ld->{$$Ld} || 0; #_check( $Pd, $Fd );

    # pA = Psmooth(Fd | Lg) = wA*P(Fd|Lg) + (1-wA)*P(Fd|Pg) # i.e. interpolate Lg-model with Pg-model
    my $wA=0.99;
    my $pFd_Lg   = $nLgFd / ($nLg || 1);
    my $pFd_Pg   = $nPgFd / ($nPg || 1);
    my $pA       = $wA * $pFd_Lg + (1-$wA)*$pFd_Pg;
    if ($pA<0.000001){$pA = 0.000001;}

    # pB = Psmooth(Ld | Fd, Lg) = wB1*P(Ld|FdLg) + wB2*P(Ld|FdPg) + wB3*P(Ld|Fd);
    # i.e. interpolate Lg-model with Pg-model and no-parent-model
    my $wB1 = ( $nLg > 50_000 ? 1 : ( $nLg / 50_000 ) ) * 0.95;
    if ($Fd =~ /^v/) {$wB1 *= 0.01;}
    my $wB2 = (1-$wB1)/2;
    my $pLd_FdLg = $nLgFdLd / ($nLgFd || 1);
    my $pLd_FdPg = $nPgFdLd / ($nPgFd || 1);
    my $pLd_Fd   = $nLdFd   / ($nFd || 1);
    my $pB       = $wB1 * $pLd_FdLg + $wB2*$pLd_FdPg + (1-$wB1-$wB2)*$pLd_Fd;
    if ($pB<0.000001){$pB = 0.000001;}

    # P(Ld,Fd | Lg) = pA * pB = P(Fd | Lg) * P(Ld | Fd, Lg)
    my $result = $pA * $pB;

    if ($verbose){
        print STDERR "Lg=$Lg (id=$$Lg #=$nLg)\tLd=$Ld (id=$$Ld #=$nLd)\tFd=$Fd (#=$nFd)\n";

        print STDERR "#LgFdLd = $nLgFdLd\t#LgFd = $nLgFd\t#PgFdLd = $nPgFdLd\t#PgFd = $nPgFd\t#Pg = $nPg\t#LdFd = $nLdFd\n";
        print STDERR "P(Fd|Lg)=$pFd_Lg\tP(Fd|Pg)=$pFd_Pg\twA=$wA\tpA=$pA\n";
        print STDERR "P(Ld|FdLg)=$pLd_FdLg\tP(Ld|FdPg)=$pLd_FdPg\tP(Ld|Fd)=$pLd_Fd\twB1=$wB1\twB2=$wB2\tpB=$pB\n";
        print STDERR "$result = result\n";
    }
    return $result;
}

# Attempt at Witten-Bell smoothing. This should be even better (and more sound)
# than the interpolation above, as no heuristics with $nLg > 50_000 are used.
sub WITTEN_BELL_get_prob_LdFd_given_Lg {
    my ( $self, $Ld, $Fd, $Lg, $verbose ) = @_;
    my $Pg = $Lg->get_pos();
    my $Pd = $Ld->get_pos();
    
    # Pointers to the two data structures
    my $cLg_FdLd = $cLgFdLd->[$$Lg];
    my $cLgFd_Ld = $cLg_FdLd->{$Fd};

    my $cPg_FdLd = $cPgFdLd->{$Pg};
    my $cPgFd_Ld = $cPg_FdLd->{$Fd};

    # Counts
    my $nLg      = $cLg_FdLd->{$ALL} || 0;
    my $nLgFd    = $cLgFd_Ld->{$ALL} || 0;
    my $nLgFdLd  = $cLgFd_Ld->{$$Ld} || 0;

    # TODO: we need cFdLd data structure, let's use the current structures meanwhile
    my $nLd      = $cLgFdLd->[$$Ld]{$ALL} || 0;
    #my $nPd      = $cPdFdLd->{$Pd}{$ALL} || 0;
    #my $nPdFd    = $cPdFdLd->{$Pd}{$Fd}{$ALL} || 0;
    my $nLdFd    = sum map {$cPgFdLd->{$_}{$Fd}{$Ld} ||0} qw(N A P C V D I T);
    my $nFd      = sum map {$cPgFdLd->{$_}{$Fd}{$ALL}||0} qw(N A P C V D I T);

    my $nPg      = $cPg_FdLd->{$ALL} || 0;
    my $nPgFd    = $cPgFd_Ld->{$ALL} || 0;
    my $nPgFdLd  = $cPgFd_Ld->{$$Ld} || 0;

    # pA = Psmooth(Fd | Lg) = wA*P(Fd|Lg) + (1-wA)*P(Fd|Pg) # interpolate Lg-model with Pg-model
    my $uniqLg_xFd = keys %{$cLg_FdLd};
    my $wA       = $nLg / (($uniqLg_xFd + $nLg)||1);
    my $pFd_Lg   = $nLgFd / ($nLg || 1);
    my $pFd_Pg   = $nPgFd / ($nPg || 1);
    my $pA       = $wA * $pFd_Lg + (1-$wA)*$pFd_Pg;
    if ($pA==0){$pA = 0.000001;}

    # Psmooth(Ld|Fd) = interpolate(P(Ld|Fd), P(Ld|Pd)*P(Pd|Fd))
    #my $pLd_Fd     = $nLdFd   / ($nFd || 1);
    #my $uniqFd_xLd = sum map {(keys %{$cPgFdLd->{$_}{$Fd}}) ||0} qw(N A P C V D I T);
    #my $wLd_Fd     = $nLdFd / (($uniqFd_xLd + $nLd)||1);
    my $pLd_Fd     = $nLdFd   / ($nFd || 1);
    #my $pLd_Pd     = $nLd / ($nPd || 1);
    #my $pPd_Fd     = $nPdFd / ($nFd || 1);
    #my $sLd_Fd     = $wLd_Fd * $pLd_Fd + (1-$wLd_Fd)*$pLd_Pd*$pPd_Fd;
    
    # Psmooth(Ld | Fd, Pg) = interpolate(P(Ld|Fd,Pg), P(Ld|Fd))
    my $uniqPgFd_xLd = keys %{$cPgFd_Ld};
    my $wLd_FdPg = $nPgFd / (($uniqPgFd_xLd + $nPgFd)||1);
    my $pLd_FdPg = $nPgFdLd / ($nPgFd || 1);
    #my $sLd_FdPg = $wLd_FdPg * $pLd_FdPg + (1-$wLd_FdPg)*$sLd_Fd;
    my $sLd_FdPg = $wLd_FdPg * $pLd_FdPg + (1-$wLd_FdPg)*$pLd_Fd;
    
    # pB = Psmooth(Ld | Fd, Lg) = interpolate(P(Ld|Fd,Lg), Psmooth(Ld|Fd,Pg))
    my $uniqLgFd_xLd = keys %{$cLgFd_Ld};
    my $wLd_FdLg = $nLgFd / (($uniqLgFd_xLd + $nLgFd)||1);
    my $pLd_FdLg = $nLgFdLd / ($nLgFd || 1);
    my $pB       = $wLd_FdLg * $pLd_FdLg + (1-$wLd_FdLg)*$sLd_FdPg;
    if ($pB==0){$pB = 0.000001;}

    # P(Ld,Fd | Lg) = pA * pB = Psmooth(Fd | Lg) * Psmooth(Ld | Fd, Lg)
    my $result = $pA * $pB;

    if ($verbose){
        print STDERR "Lg=$Lg (id=$$Lg #=$nLg)\tLd=$Ld (id=$$Ld #=$nLd)\tFd=$Fd (#=$nFd)\n";

        print STDERR "#LgFdLd = $nLgFdLd\t#LgFd = $nLgFd\t#PgFdLd = $nPgFdLd\t#PgFd = $nPgFd\t#Pg = $nPg\t#LdFd = $nLdFd\n";
        print STDERR "P(Fd|Lg)=$pFd_Lg\tP(Fd|Pg)=$pFd_Pg\twA=$wA\tpA=$pA\n";
        print STDERR "P(Ld|FdLg)=$pLd_FdLg\tP(Ld|FdPg)=$pLd_FdPg\tP(Ld|Fd)=$pLd_Fd\twLd_FdPg=$wLd_FdPg\twLd_FdLg=$wLd_FdLg\tpB=$pB\n";
        print STDERR "$result = result\n";
    }
    return $result;
}

# (unmodified) Kneser-Ney smoothing
sub KNESER_NEY_get_prob_LdFd_given_Lg {
    my ( $self, $Ld, $Fd, $Lg, $verbose ) = @_;
    my $Pg = $Lg->get_pos();
    my $Pd = $Ld->get_pos();
    
    # Pointers to the two data structures
    my $cLg_FdLd = $cLgFdLd->[$$Lg];
    my $cLgFd_Ld = $cLg_FdLd->{$Fd};

    my $cPg_FdLd = $cPgFdLd->{$Pg};
    my $cPgFd_Ld = $cPg_FdLd->{$Fd};

    # Counts
    my $nLg      = $cLg_FdLd->{$ALL} || 0;
    my $nLgFd    = $cLgFd_Ld->{$ALL} || 0;
    my $nLgFdLd  = $cLgFd_Ld->{$$Ld} || 0;

    # TODO: we need cFdLd data structure, let's use the current structures meanwhile
    my $nLd      = $cLgFdLd->[$$Ld]{$ALL} || 0;
    #my $nPd      = $cPdFdLd->{$Pd}{$ALL} || 0;
    #my $nPdFd    = $cPdFdLd->{$Pd}{$Fd}{$ALL} || 0;
    my $nLdFd    = sum map {$cPgFdLd->{$_}{$Fd}{$Ld} ||0} qw(N A P C V D I T);
    my $nFd      = sum map {$cPgFdLd->{$_}{$Fd}{$ALL}||0} qw(N A P C V D I T);

    my $nPg      = $cPg_FdLd->{$ALL} || 0;
    my $nPgFd    = $cPgFd_Ld->{$ALL} || 0;
    my $nPgFdLd  = $cPgFd_Ld->{$$Ld} || 0;

    # pA = Psmooth(Fd | Lg) = backoff from Lg-model to Pg-model
    my $pA;
    if ($nLgFd){ $pA = ($nLgFd - discount(1,$nLgFd)) / $nLg;}
    else {
        my $d = discount(1,$nLgFd);
        # bow(a_) = (1 - Sum_Z1 f(a_z)) / (1 - Sum_Z1 f(_z))
        # bow(Lg) = (1 - Sum_Fd((nLgFd-discount(1,nLgFd))/nLg) / (1 - sum_Fd pFd_Pg)
        my $bow; # TODO must be precomputed (third column in APRA files)
        my $pFd_Pg   = ($nPgFd+1) / ($nPg+1);
        $pA = $bow * $pFd_Pg;
    }
    #TODO
}


=head1 NAME

Treex::Tool::LM::TreeLM

=head1 AUTHOR

Martin Popel

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
