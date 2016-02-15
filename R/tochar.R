# @include S4.R

NULL

# Compute the ranges of a hunk group based on atomic hunk ids
#
# rng and rng.o are matrices where each column represents `c(tar.rng, cur.rng)`
# and rng.o has the original untrimmed values

find_rng <- function(ids, rng, rng.o) {
  with.rng <- ids[which(rng[1L, ids] > 0L)]
  if(!length(with.rng)) {
    # Find previous earliest originally existing item we want to insert
    # after; note we need to look at the non-trimmed ranges, and we include
    # the first context atomic hunk in the group as a potential match
    prev <- rng.o[
      2L, seq_len(ncol(rng.o)) <= max(ids[[1L]], 0L) &
        rng.o[1L, ] > 0L
    ]
    if(!length(prev)) integer(2L) else c(max(prev), 0L)
  } else {
    c(min(rng[1L, intersect(ids, with.rng)]), max(rng[2L, ids]))
  }
}
# Create a text representation of a file line range

rng_as_chr <- function(range) {
  a <- range[[1L]]
  b <- if(diff(range))
    paste0(",", if(range[[2L]]) diff(range) + 1L else 0)
  paste0(a, b)
}
# Convert a hunk group into text representation

hunk_as_char <- function(h.g, ranges, ranges.orig, mode, use.ansi, width) {
  h.ids <- vapply(h.g, "[[", integer(1L), "id")
  tar.rng <- find_rng(h.ids, ranges[1:2, ], ranges.orig[1:2, ])
  cur.rng <- find_rng(h.ids, ranges[3:4, ], ranges.orig[3:4, ])

  hh.a <- paste0("-", rng_as_chr(tar.rng))
  hh.b <- paste0("+", rng_as_chr(cur.rng))

  hunk.head <- ansi_style(
    if(mode == "sidebyside") {
      paste0(
        rpadt(sprintf("@@ %s @@", hh.a), width),
        rpadt(sprintf("@@ %s @@", hh.b), width),
        collapse=""
      )
    } else {
      sprintf("@@ %s %s @@", hh.a, hh.b)
    },
    "cyan", use.ansi
  )
  # Output varies by mode

  diff.txt <- if(mode == "context") {
    # Need to get all the A data and the B data
    get_chr_vals <- function(h.a, ind) wrap(h.a[[ind]], width - 2L, use.ansi)

    A.ctx <- unlist(
      lapply(h.g, function(h.a) rep(h.a$context, length(h.a$A.chr)))
    )
    B.ctx <- unlist(
      lapply(h.g, function(h.a) rep(h.a$context, length(h.a$B.chr)))
    )
    A <- as.list(unlist(lapply(h.g, get_chr_vals, "A.chr")))
    B <- as.list(unlist(lapply(h.g, get_chr_vals, "B.chr")))

    A[!A.ctx] <- sign_pad(A[!A.ctx], 3L, use.ansi=use.ansi)
    B[!B.ctx] <- sign_pad(B[!B.ctx], 2L, use.ansi=use.ansi)
    A[A.ctx] <- sign_pad(A[A.ctx], 1L, use.ansi=use.ansi)
    B[B.ctx] <- sign_pad(B[B.ctx], 1L, use.ansi=use.ansi)
    unlist(c(A, ansi_style("----", "silver", use.style=use.ansi), B))
  } else if(mode == "unified") {
    unlist(
      lapply(h.g,
        function(h.a) {
          pos <- h.a$A > 0L
          A.out <- wrap(h.a$A.chr, width - 2L, use.ansi=use.ansi)
          if(!h.a$context) {
            A.out[pos] <- sign_pad(A.out[pos], 3L, use.ansi=use.ansi)
            A.out[!pos] <- sign_pad(A.out[!pos], 2L, use.ansi=use.ansi)
          } else {
            A.out <- sign_pad(A.out, 1L, use.ansi=use.ansi)
          }
          A.out
    } ) )
  } else if(mode == "sidebyside") {
    unlist(
      lapply(h.g,
        function(h.a) {
          # Ensure same number of elements in A and B

          A.out <- h.a$A.chr
          B.out <- h.a$B.chr
          A.present <- rep(TRUE, length(A.out))
          B.present <- rep(TRUE, length(B.out))
          len.diff <- length(A.out) - length(B.out)

          if(len.diff < 0L) {
            A.out <- c(A.out, character(abs(len.diff)))
            A.present <- c(A.present, rep(FALSE, abs(len.diff)))
          } else if(len.diff) {
            B.out <- c(B.out, character(len.diff))
            B.present <- c(B.present, rep(FALSE, len.diff))
          }
          A.w <- wrap(A.out, width - 2L, use.ansi=use.ansi, pad=TRUE)
          B.w <- wrap(B.out, width - 2L, use.ansi=use.ansi, pad=TRUE)

          # Same number of els post wrap

          A.lens <- sum(vapply(A.w, length, integer(1L)))
          B.lens <- sum(vapply(B.w, length, integer(1L)))
          len.max <- max(A.lens, B.lens)
          blanks <- paste0(rep(" ", width), collapse="")

          for(i in seq_along(len.max)) {
            if(A.lens < B.lens)
              A.w[[i]] <- c(A.w[[i]], rep(blanks, B.lens - A.lens))
            if(A.lens > B.lens)
              B.w[[i]] <- c(B.w[[i]], rep(blanks, A.lens - B.lens))
          }
          if(A.lens || B.lens) {
            paste0(
              unlist(
                sign_pad(
                  A.w, ifelse(!h.a$context & A.present, 3L, 1L),
                  use.ansi=use.ansi
              ) ),
              unlist(
                sign_pad(
                  B.w, ifelse(!h.a$context & B.present, 2L, 1L),
                  use.ansi=use.ansi
          ) ) ) }
  } ) ) }
  c(hunk.head, diff.txt)
}
#' @rdname diffobj_s4method_doc

setMethod("as.character", "diffObjDiff",
  function(x, hunk.limit, line.limit, width, use.ansi, mode, ...) {
    # These checks should never fail since presumably the inputs have been
    # checked earlier; here just in case we mess something up in devel or
    # testing

    context <- check_linelimit(line.limit)
    width <- check_width(width)
    mode <- check_mode(mode)
    white.space <- x@diffs@white.space

    len.max <- max(length(x@tar.capt), length(x@cur.capt))
    if(!any(x)) {
      msg <- "No visible differences between objects."
      if(!x@diffs@white.space && !identical(x@tar.capt, x@cur.capt)) {
        msg <- paste0(
          "Only visible differences between objects are horizontal white ",
          "spaces. You can re-run diff with `white.space=TRUE` to show them."
        )
      }
      return(
        ansi_style(
          msg, "silver",
          use.style=use.ansi
    ) ) }
    # Figure out which hunks we're going to try to render subject to the
    # line and hunk limits.  Remember

    # Trim hunks to the extent need to make sure we fit in lines; start by
    # dropping hunks beyond hunk limit

    hunk.grps <- trim_hunks(
      x@diffs@hunks, mode=mode, width=width, line.limit=line.limit,
      hunk.limit=hunk.limit, use.ansi=use.ansi
    )
    # Post trim, figure out max lines we could possibly be showing from capture
    # strings; careful with ranges,

    hunks.flat <- unlist(hunk.grps, recursive=FALSE)
    ranges <- vapply(
      hunks.flat, function(h.a)
        c(h.a$tar.rng.trim, h.a$cur.rng.trim),
      integer(4L)
    )
    ranges.orig <- vapply(
      hunks.flat, function(h.a) c(h.a$tar.rng, h.a$cur.rng), integer(4L)
    )
    tar.max <- max(ranges[2L, ])
    cur.max <- max(ranges[4L, ])

    # Detect whether we should attempt to deal with wrapping objects, if so
    # overwrite cur/tar.body/rest variables with the color diffed wrap word
    # diffs; note that if the tar/cur.capt.def is not NULL then the objects
    # being compared must be atomic vectors

    cur.body <- tar.body <- character(0L)
    cur.rest <- show.range.cur <- seq_len(cur.max)
    tar.rest <- show.range.tar <- seq_len(tar.max)

    if(
      identical(x@mode, "print") && identical(x@tar.capt, x@tar.capt.def) &&
      identical(x@cur.capt, x@cur.capt.def)
    ) {
      # Separate out the stuff that can wrap (starts with index headers vs. not),
      # and for that stuff only, apply the color word diff

      cur.head.raw <- find_brackets(x@cur.capt)
      tar.head.raw <- find_brackets(x@tar.capt)

      cur.head <- cur.head.raw[cur.head.raw %in% show.range.cur]
      tar.head <- tar.head.raw[tar.head.raw %in% show.range.tar]

      if(length(cur.head) && length(tar.head)) {
        # note we modify `x` here so that subsequent steps can re-use `x` with
        # modifications

        pat <- sprintf("%s\\K.*", .brack.pat)
        cur.body <- regexpr(pat, x@cur.capt[cur.head], perl=TRUE)
        tar.body <- regexpr(pat, x@tar.capt[tar.head], perl=TRUE)

        body.diff <- diff_word(
          regmatches(x@tar.capt[tar.head], tar.body),
          regmatches(x@cur.capt[cur.head], cur.body),
          across.lines=TRUE, white.space=white.space,
          match.quotes=is.chr.vec(x@tar.obj) && is.chr.vec(x@cur.obj)
        )
        regmatches(x@tar.capt[tar.head], tar.body) <- body.diff$target
        regmatches(x@cur.capt[cur.head], cur.body) <- body.diff$current

        # We also need to diff the row headers

        cur.r.h <- regexpr(.brack.pat, x@cur.capt[cur.head], perl=TRUE)
        tar.r.h <- regexpr(.brack.pat, x@tar.capt[tar.head], perl=TRUE)

        cur.r.h.txt <- regmatches(x@cur.capt[cur.head], cur.r.h)
        tar.r.h.txt <- regmatches(x@tar.capt[tar.head], tar.r.h)

        x.r.h <- new(
          "diffObjDiff", tar.capt=tar.r.h.txt, cur.capt=cur.r.h.txt,
          diffs=char_diff(tar.r.h.txt, cur.r.h.txt, white.space=white.space)
        )
        x.r.h.color <- diffColor(x.r.h, use.ansi=use.ansi)
        regmatches(x@tar.capt[tar.head], tar.r.h) <- x.r.h.color$A
        regmatches(x@cur.capt[cur.head], cur.r.h) <- x.r.h.color$B

        # Everything else gets a normal hunk by hunk word diff

        cur.rest <- show.range.cur[!show.range.cur %in% cur.head]
        tar.rest <- show.range.tar[!show.range.tar %in% tar.head]
      }
    }
    # Figure out which hunks are still eligible to be word diffed

    tar.to.wd <- which(ranges[1L,] %in% tar.rest)
    cur.to.wd <- which(ranges[3L,] %in% cur.rest)

    if(length(tar.to.wd) && length(cur.to.wd)) {
      wd.max <- min(tar.to.wd[[1L]], cur.to.wd[[1L]])

      # We need to compare the +s to the -s, and then reconstruct back into
      # the original A and B vectors

      for(i in seq_along(hunk.grps)) {
        for(j in seq_along(hunk.grps[[i]])) {
          h.a <- hunk.grps[[i]][[j]]
          # Skip context or those that have been wrap diffed
          if(h.a$id < wd.max || h.a$context) next
          # Do word diff on each non-context hunk; real messy because the
          # stuff from `tar` and `cur` are mixed in in A and B (well, really
          # only in unified mode) so we have to separate it back out before
          # we do the diff

          A.pos <- which(h.a$A > 0L)
          B.pos <- which(h.a$B > 0L)
          A.neg <- which(h.a$A < 0L)
          B.neg <- which(h.a$B < 0L)

          A.new <- c(h.a$A.chr[A.pos], h.a$B.chr[B.pos])
          B.new  <- c(h.a$A.chr[A.neg], h.a$B.chr[B.neg])

          new.diff <- diff_word(
            A.new, B.new, across.lines=TRUE, white.space=white.space,
            use.ansi=use.ansi
          )
          h.a$A.chr[A.pos] <- new.diff$target[seq_along(A.pos)]
          h.a$A.chr[A.neg] <- new.diff$current[seq_along(A.neg)]
          h.a$B.chr[B.pos] <- new.diff$target[seq_along(B.pos) + length(A.pos)]
          h.a$B.chr[B.neg] <- new.diff$current[seq_along(B.neg) + length(A.neg)]

          hunk.grps[[i]][[j]] <- h.a
    } } }
    # Make the object banner and compute widths

    banner.A <- paste0("--- ", deparse(x@tar.exp)[[1L]])
    banner.B <- paste0("+++ ", deparse(x@cur.exp)[[1L]])

    if(mode == "sidebyside") {
      # If side by side we want stuff close together if reasonable
      max.col.w <- max(
        unlist(lapply(hunks.flat, function(x) nchar(c(x$A.chr, x$B.chr))))
      )
      max.w <- if(max.col.w < floor(width / 2))
        max(15L, max.col.w) else max(floor(width / 2), 20L)
      comb.fun <- paste0
      t.fun <- rpadt
    } else {
      max.w <- max(width, 20L)
      comb.fun <- c
      t.fun <- chr_trim
    }
    banner <- comb.fun(
      ansi_style(t.fun(banner.A, max.w), "red", use.ansi),
      ansi_style(t.fun(banner.B, max.w), "green", use.ansi)
    )
    # Process the actual hunks into character

    out <- lapply(
      hunk.grps, hunk_as_char, ranges=ranges, ranges.orig=ranges.orig,
      mode=mode, use.ansi=use.ansi, width=max.w
    )
    c(banner, unlist(out))
} )