use Test2::Bundle::Extended;
use Alien::Build::Util qw( _dump _mirror );
use Path::Tiny;
use IPC::Cmd qw( can_run );
use Capture::Tiny qw( capture_merged );
use Env qw( @PATH );
use Config;

subtest 'dump' => sub {

  my $dump = _dump { a => 1, b => 2 }, [ 1..2 ];
  
  isnt $dump, '';
  
  note $dump;

};

subtest 'mirror' => sub {

  if($^O eq 'MSWin32' && ! can_run 'diff')
  {
    if(eval { require Alien::MSYS })
    {
      unshift @PATH, Alien::MSYS::msys_path();
    }
  }

  skip_all 'test requires diff' unless can_run 'diff';

  my $tmp1 = Path::Tiny->tempdir("mirror_src_XXXX");
    
  ok -d $tmp1, 'created source directory';

  $tmp1->child($_)->mkpath foreach qw( bin etc lib lib/pkgconfig an/empty/one/as/well );
    
  my $bin = $tmp1->child('bin/foomake');
  $bin->spew("#!/bin/sh\necho hi\n");
  eval { chmod 0755, $bin };
    
  $tmp1->child('etc/foorc')->spew("# example\nfoo = 1\n");
  my $lib = $tmp1->child('lib/libfoo.so.1.2.3');
  $lib->spew('XYZ');
  $tmp1->child('lib/pkgconfig/foo.pc')->spew('name=foo');
    
  if($Config{d_symlink})
  {
    foreach my $new (map { $tmp1->child("lib/libfoo$_") } qw( .so.1.2 .so.1 .so ))
    {
      my $old = 'libfoo.so.1.2.3';
      symlink($old, $new->stringify) || die "unable to symlink $new => $old $!";
    }
  }
    
  my $tmp2 = Path::Tiny->tempdir("mirror_dst_XXXX");

  _mirror "$tmp1", "$tmp2";
    
  my($out, $exit) = capture_merged { system 'diff', '-r', "$tmp1", "$tmp2" };
  
  is $exit, 0, 'diff -r returned true';
   
  $exit ? diag $out : note $out if $out ne '';
  
  if(-x $tmp1->child('bin/foomake'))
  {
    ok(-x $tmp2->child('bin/foomake'), 'dst bin/foomake is executable');
  }
};

done_testing;